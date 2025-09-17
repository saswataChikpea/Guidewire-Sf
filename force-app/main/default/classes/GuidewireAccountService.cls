public without sharing class GuidewireAccountService {
    
    public static List<Account> upsertAccountsFromJson(String jsonString) {
        List<Account> accountsToUpsert = new List<Account>();
        List<Account> upsertedAccounts = new List<Account>();
        
        // Parse JSON
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        if (!parsed.containsKey('included')) return upsertedAccounts;
        Map<String, Object> included = (Map<String, Object>) parsed.get('included');
        if (!included.containsKey('Account')) return upsertedAccounts;
        List<Object> accountsList = (List<Object>) included.get('Account');
        
        // Query field mappings for Account
        List<Guidewire_Salesforce_Field_Mapping__c> mappings = [
        SELECT GuidewireField__c, SalesforceField__c, SalesforceFieldType__c
        FROM Guidewire_Salesforce_Field_Mapping__c
        WHERE SalesforceObject__c = 'Account'
        ];
        Map<String, Guidewire_Salesforce_Field_Mapping__c> mappingByGwField = new Map<String, Guidewire_Salesforce_Field_Mapping__c>();
        for (Guidewire_Salesforce_Field_Mapping__c m : mappings) {
            // keep original case so we can match JSON keys
            mappingByGwField.put(m.GuidewireField__c, m);
        }
        
        // Loop through accounts in JSON
        for (Object accObj : accountsList) {
            Map<String, Object> accMap = (Map<String, Object>) accObj;
            if (!accMap.containsKey('attributes')) continue;
            System.debug('Account attributes: ' + accMap.get('attributes'));
            
            Map<String, Object> attributesMap = (Map<String, Object>) accMap.get('attributes');
            
            Account accRecord = new Account();
            System.debug('Processing account attributes: ' + attributesMap);
            
            // Map fields based on Guidewire_Salesforce_Field_Mapping__c
            System.debug('Field mappings: ' + mappingByGwField.keySet());
            for (String gwField : mappingByGwField.keySet()) {
                //System.debug('Mapping Guidewire field: ' + gwField);
                String path = gwField;
                if (path.startsWith('included.account.attributes.')) {
                    path = path.substring('included.account.attributes.'.length());
                }
                Object value = getValueFromPath(attributesMap, path);
                //Object value = getValueFromPath(attributesMap, gwField); // supports nested path
                if (value != null) {
                    Guidewire_Salesforce_Field_Mapping__c m = mappingByGwField.get(gwField);
                    String sfField = m.SalesforceField__c;
                    String sfType = m.SalesforceFieldType__c;
                    //String sfField = mappingByGwField.get(gwField).SalesforceField__c;
                    // skip Initial Account Holder for now (lookup field)
                    if (sfField == 'GW_Initial_Account_Holder__c' || sfType == 'Lookup') {
                        continue;
                    }
                    Object converted;
                    
                    if (sfType == 'DateTime') {
                        String dateStr = (value instanceof String) ? (String)value : String.valueOf(value);
                        dateStr = dateStr.replace('T',' ');
                        if (dateStr.endsWith('Z')) {
                            dateStr = dateStr.removeEnd('Z');
                        }
                        converted = Datetime.valueOf(dateStr.trim());
                        
                    } else if (sfType == 'Date') {
                        String dateStr = (value instanceof String) ? (String)value : String.valueOf(value);
                        converted = Date.valueOf(dateStr.substring(0,10));
                        
                    } else if (sfType == 'Number') {
                        converted = (value instanceof Decimal) ? (Decimal)value : Decimal.valueOf(String.valueOf(value));
                        
                    } else if (sfType == 'Checkbox') {
                        if (value instanceof Boolean) {
                            converted = (Boolean)value;
                        } else {
                            converted = Boolean.valueOf(String.valueOf(value));
                        }
                        
                    } else {
                        // default: just treat as string
                        converted = (value instanceof String) ? (String)value : String.valueOf(value);
                    }
                    
                    accRecord.put(sfField, converted);
                    
                    //System.debug('Extracted ' + sfField + ': ' + converted);
                    String originalType =
                        (value instanceof String)  ? 'String' :
                        (value instanceof Decimal) ? 'Decimal' :
                        (value instanceof Boolean) ? 'Boolean' :
                        (value instanceof Date)    ? 'Date' :
                        (value instanceof Datetime)? 'Datetime' :
                        (value instanceof Map<String,Object>) ? 'Map' :
                        (value instanceof List<Object>) ? 'List' :
                        'Unknown';
                    
                    String convertedType =
                        (converted instanceof String)  ? 'String' :
                        (converted instanceof Decimal) ? 'Decimal' :
                        (converted instanceof Boolean) ? 'Boolean' :
                        (converted instanceof Date)    ? 'Date' :
                        (converted instanceof Datetime)? 'Datetime' :
                        (converted instanceof Map<String,Object>) ? 'Map' :
                        (converted instanceof List<Object>) ? 'List' :
                        'Unknown';
                    
                    // System.debug('Converted ' + sfField + ' from ' + originalType + ' to ' + convertedType);
                    
                    
                }
            }
            
            System.debug('Extracted Guidewire_ID__c after mapping: ' + accRecord.Guidewire_ID__c);
            System.debug('AttributesMap keys: ' + attributesMap.keySet());
            System.debug('Looking for path: accountHolder.id');
            System.debug('Value found: ' + getValueFromPath(attributesMap, 'accountHolder.id'));
            
            
            // Skip if Guidewire_ID__c missing
            if (String.isNotBlank(accRecord.Guidewire_ID__c)) {
                accountsToUpsert.add(accRecord);
            } else {
                System.debug('Skipping account: Guidewire_ID__c missing in JSON');
            }
        }
        
        // Upsert using Guidewire_ID__c as external ID
        if (!accountsToUpsert.isEmpty()) {
            upsert accountsToUpsert Guidewire_ID__c;
            System.debug('Upserted accounts: ' + accountsToUpsert);
            
            // Query back to return inserted/updated accounts
            List<String> gwIds = new List<String>();
            for (Account a : accountsToUpsert) {
                gwIds.add(a.Guidewire_ID__c);
            }
            upsertedAccounts = [
            SELECT Id, Name, Guidewire_ID__c
            FROM Account
            WHERE Guidewire_ID__c IN :gwIds
        ];
        }
        System.debug('Final upserted accounts: ' + upsertedAccounts);
        
        return upsertedAccounts;
    }
    
    /**
     * Get value from nested JSON path using dot notation (case-insensitive keys)
     */
    private static Object getValueFromPath(Map<String, Object> mapData, String path) {
        String[] parts = path.split('\\.');
        Object current = mapData;
        
        // System.debug('Getting value from path: ' + parts);
        
        for (String p : parts) {
            if (current instanceof Map<String, Object>) {
                Map<String, Object> curMap = (Map<String, Object>) current;
                // case-insensitive match for key
                String matchKey = null;
                for (String key : curMap.keySet()) {
                    if (key.toLowerCase() == p.toLowerCase()) {
                        matchKey = key;
                        break;
                    }
                }
                if (matchKey != null) {
                    current = curMap.get(matchKey);
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
        return current;
    }
    
    
    
    
    
    
    public static void updateAccountInGW(Account acc) {
        try {
            // Step 1: Build JSON body dynamically
            String bodyJson = GuidewireJsonBuilder.buildBody(acc, 'Account');
            System.debug('Guidewire PATCH Body: ' + bodyJson);
            
            // Step 2: Prepare HTTP callout
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            
            // Use Named Credential for authentication + base URL
            // Named Credential should be created as 'Guidewire_API'
            req.setEndpoint('callout:Guidewire_API/accounts/' + acc.AccountNumber);
            req.setMethod('PATCH');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(bodyJson);
            
            // Step 3: Send request
            HttpResponse res = http.send(req);
            
            // Step 4: Handle response
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug(' Guidewire update success: ' + res.getBody());
            } else {
                System.debug(' Guidewire update failed: ' + res.getStatusCode() + ' - ' + res.getBody());
                // Optionally log error in a custom object
                GuidewireUtilityClass.logIntegrationError(acc.Id, res.getStatusCode(), res.getBody());
            }
            
        } catch (Exception e) {
            System.debug('Guidewire update exception: ' + e.getMessage());
            GuidewireUtilityClass.logIntegrationError(acc.Id, 500, e.getMessage());
        }
    }
    
    /**
     * Log integration errors for monitoring/retry
     */
    
}