/*
-------------------------------------------------------------------------------
    Class Name     : GuidewireAccountService
    Author         : Saswata Banerjee
    Created Date   : 2025-09-17
    Last Modified  : 2025-09-18
    Description    : Utility class for Guidewire integration to upsert Accounts in Salesforce with the JSON payload from Guidewire.
    Also has method to update Account in Guidewire via PATCH callout.
    Usage          : Used by GuidewireUpdateSfAccount Apex class and can be used in future by other classes.
    Dependencies   :
    Notes          :
    -------------------------------------------------------------------------------
     */
public with sharing class GuidewireAccountService {
    
    public static List<Account> upsertAccountsFromJson(String jsonString) {
        List<Account> accountsToUpsert = new List<Account>();
        List<Account> upsertedAccounts = new List<Account>();
        
        try {
            // System.debug(' Guidewire JSON: ' + jsonString);
            // Parse JSON
            System.debug(' json string: ' + jsonString.length());
            
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
            //System.debug(' Parsed: ' + parsed);
            
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
            
            System.debug(' Mappings found: ' + mappings.size());
            Map<String, Guidewire_Salesforce_Field_Mapping__c> mappingByGwField = new Map<String, Guidewire_Salesforce_Field_Mapping__c>();
            for (Guidewire_Salesforce_Field_Mapping__c m : mappings) {
                mappingByGwField.put(m.GuidewireField__c, m);
            }
            System.debug(' Field mappings: ' + mappingByGwField);
            // Loop through accounts in JSON
            for (Object accObj : accountsList) {
                try {
                    Map<String, Object> accMap = (Map<String, Object>) accObj;
                    if (!accMap.containsKey('attributes')) continue;
                    Map<String, Object> attributesMap = (Map<String, Object>) accMap.get('attributes');
                    
                    Account accRecord = new Account();
                    
                    // Map fields based on Guidewire_Salesforce_Field_Mapping__c
                    for (String gwField : mappingByGwField.keySet()) {
                        String path = gwField;
                        if (path.startsWith('included.account.attributes.')) {
                            path = path.substring('included.account.attributes.'.length());
                        }
                        System.debug(' Processing path: ' + path.toLowerCase());
                        if (path.toLowerCase().startsWith('initialaccountholder.officialids')) {
                            System.debug('Skipping officialIds path: ' + path);
                            continue;
                        }
                        Object value = getValueFromPath(attributesMap, path);
                        // the JSON returns a Map, only take the displayName key
                        // System.debug('Value: ' + value);
                        if (value instanceof Map<String, Object>) {
                            Map<String, Object> valMap = (Map<String, Object>) value;
                            if (valMap.containsKey('displayName')) {
                                value = valMap.get('displayName');
                            }
                        }
                        if (value != null) {
                            Guidewire_Salesforce_Field_Mapping__c m = mappingByGwField.get(gwField);
                            String sfField = m.SalesforceField__c;
                            String sfType = m.SalesforceFieldType__c;
                            if (sfField == 'GW_Initial_Account_Holder__c' || sfType == 'Lookup') continue;
                            
                            Object converted;
                            
                            if (sfType == 'DateTime') {
                                String dateStr = (value instanceof String) ? (String)value : String.valueOf(value);
                                dateStr = dateStr.replace('T',' ');
                                if (dateStr.endsWith('Z')) dateStr = dateStr.removeEnd('Z');
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
                                converted = (value instanceof String) ? (String)value : String.valueOf(value);
                            }
                            // System.debug(' Trying to map ' + path + ' to ' + sfField + '. Raw value=' + JSON.serialize(value));
                            
                            accRecord.put(sfField, converted);
                        }
                    }
                    
                    // Skip if Guidewire_ID__c missing
                    if (String.isNotBlank(accRecord.Guidewire_ID__c)) {
                        accountsToUpsert.add(accRecord);
                    }
                    
                } catch (Exception eAcc) {
                    System.debug(' Error processing an account: ' + eAcc.getMessage());
                    // Log the error with null recordId since account creation failed
                    GuidewireUtilityClass.logIntegrationError(null, 500, 'Error processing account: ' + eAcc.getMessage());
                }
            }
            
            // Upsert using Guidewire_ID__c as external ID
            try {
                if (!accountsToUpsert.isEmpty()) {
                    upsert accountsToUpsert Guidewire_ID__c;
                    
                    List<String> gwIds = new List<String>();
                    for (Account a : accountsToUpsert) gwIds.add(a.Guidewire_ID__c);
                    
                    upsertedAccounts = [
                        SELECT Id, Name, Guidewire_ID__c
                        FROM Account
                        WHERE Guidewire_ID__c IN :gwIds
                    ];
                }
            } catch (DmlException dmlEx) {
                System.debug('DML error during account upsert: ' + dmlEx.getMessage());
                
                for (Account a : accountsToUpsert) {
                    GuidewireUtilityClass.logIntegrationError(a.Id, 500, 'DML error: ' + dmlEx.getMessage());
                }
            }
            
        } catch (Exception e) {
            System.debug(' Error parsing JSON or initializing mappings: ' + e.getMessage());
            GuidewireUtilityClass.logIntegrationError(null, 500, 'JSON parsing/init error: ' + e.getMessage());
        }
        
        return upsertedAccounts;
    }
    
    private static Object getValueFromPath(Map<String, Object> mapData, String path) {
        String[] parts = path.split('\\.');
        Object current = mapData;
        for (String p : parts) {
            if (current instanceof Map<String, Object>) {
                Map<String, Object> curMap = (Map<String, Object>) current;
                String matchKey = null;
                for (String key : curMap.keySet()) {
                    if (key.toLowerCase() == p.toLowerCase()) {
                        matchKey = key;
                        break;
                    }
                }
                if (matchKey != null) current = curMap.get(matchKey);
                else return null;
            } else return null;
        }
        return current;
    }
    
    
    @InvocableMethod
    public static void updateAccountInGW(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        
        Id accId = accountIds[0];
        
        // Dynamically get all fields
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        String soql = 'SELECT ';
        
        // Build field list
        List<String> fieldNames = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            fieldNames.add(fieldName);
        }
        soql += String.join(fieldNames, ', ');
        soql += ' FROM Account WHERE Id = :accId LIMIT 1';
        
        // Run dynamic SOQL
        Account acc = Database.query(soql);
        
        try {
            // Step 1: Build JSON body dynamically
            String bodyJson = GuidewireJsonBuilder.buildBody(acc, 'Account');
            System.debug('Guidewire PATCH Body: ' + bodyJson);
            
            // Step 2: Prepare HTTP callout
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            
            // Use Named Credential for authentication + base URL
            // Named Credential should be created as 'Guidewire_API'
            req.setEndpoint('callout:GuidewireMockNC/accounts/' + acc.AccountNumber);
            req.setMethod('PATCH');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(bodyJson);
            
            // Step 3: Send request
            HttpResponse res = http.send(req);
            
            // Step 4: Handle response
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug(' Guidewire update success: ');
            } else {
                System.debug(' Guidewire update failed: ');
                // Optionally log error in a custom object
                GuidewireUtilityClass.logIntegrationError(acc.Id, res.getStatusCode(), res.getBody());
            }
            
        } catch (Exception e) {
            System.debug('Guidewire update exception: ' + e.getMessage());
            GuidewireUtilityClass.logIntegrationError(acc.Id, 500, e.getMessage());
        }
    }
    
    public static void createAccountInGW(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        
        Id accId = accountIds[0];
        
        // Dynamically get all fields
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        String soql = 'SELECT ';
        
        // Build field list
        List<String> fieldNames = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            fieldNames.add(fieldName);
        }
        soql += String.join(fieldNames, ', ');
        soql += ' FROM Account WHERE Id = :accId LIMIT 1';
        
        // Run dynamic SOQL
        Account acc = Database.query(soql);
        
        try {
            // Step 1: Build JSON body dynamically
            String bodyJson = GuidewireJsonBuilder.buildBody(acc, 'Account');
            System.debug('Guidewire PATCH Body: ' + bodyJson);
            
            // Step 2: Prepare HTTP callout
            HttpRequest req = new HttpRequest();
            Http http = new Http();
            
            // Use Named Credential for authentication + base URL
            // Named Credential should be created as 'Guidewire_API'
            req.setEndpoint('callout:GuidewireMockNC/accounts/v1/accounts');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(bodyJson);
            
            // Step 3: Send request
            HttpResponse res = http.send(req);
            
            // Step 4: Handle response
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug(' Guidewire create success: ');
            } else {
                System.debug(' Guidewire create failed: ');
                // Optionally log error in a custom object
                GuidewireUtilityClass.logIntegrationError(acc.Id, res.getStatusCode(), res.getBody());
            }
            
        } catch (Exception e) {
            System.debug('Guidewire update exception: ' + e.getMessage());
            GuidewireUtilityClass.logIntegrationError(acc.Id, 500, e.getMessage());
        }
    }
    
    
    
    
}