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
    
    
    @AuraEnabled
    public static String syncAccountAndContacts(String accountId, String gwJson) {
        
        
        try {
            Account a = [SELECT Id,Name, Guidewire_ID__c FROM Account WHERE Guidewire_ID__c = 'pc:10001' limit 1];
            System.debug('Account found with Guidewire_ID__c: ' + accountId + ', Salesforce Id: ' + a.Id);
            accountId = a.id;
        } catch (Exception e) {
            System.debug('No Account found with Guidewire_ID__c: ' + accountId);
        }
        
        
        
        System.debug('=== syncAccountAndContacts START for AccountId: ' + accountId + ' ===');
        try {
            // 1. Upsert the Account as usual
            System.debug('Calling upsertAccountsFromJson...');
            upsertAccountsFromJson(gwJson);
            System.debug('Account upsert complete, now processing contacts for AccountId: ' + accountId);
            
            // 2. Handle AccountContact section
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(gwJson);
            if (!parsed.containsKey('included')) {
                System.debug('No included section found in JSON');
                return 'No included section';
            }
            Map<String, Object> included = (Map<String, Object>) parsed.get('included');
            if (!included.containsKey('AccountContact')) {
                System.debug('No AccountContact section found in JSON');
                return 'No AccountContact section';
            }
            List<Object> accContacts = (List<Object>) included.get('AccountContact');
            System.debug('AccountContact count from JSON: ' + accContacts.size());
            
            // Existing contacts for the Account
            Map<String, Contact> existingContacts = new Map<String, Contact>();
            for (Contact c : [SELECT Id, Guidewire_ID__c, LastName FROM Contact WHERE AccountId = :accountId]) {
                existingContacts.put(c.Guidewire_ID__c, c);
            }
            System.debug('Existing contacts found in Salesforce: ' + existingContacts.size());
            
            // Field mappings for Contact
            Map<String, Guidewire_Salesforce_Field_Mapping__c> contactMapping = new Map<String, Guidewire_Salesforce_Field_Mapping__c>();
            for (Guidewire_Salesforce_Field_Mapping__c m : [
            SELECT GuidewireField__c, SalesforceField__c, SalesforceFieldType__c
            FROM Guidewire_Salesforce_Field_Mapping__c
            WHERE SalesforceObject__c = 'Contact'
        ]) {
                contactMapping.put(m.GuidewireField__c, m);
            }
            System.debug('Contact field mappings loaded: ' + contactMapping.size());
            
            // Field mappings for Account
            Map<String, Guidewire_Salesforce_Field_Mapping__c> accountMapping = new Map<String, Guidewire_Salesforce_Field_Mapping__c>();
            for (Guidewire_Salesforce_Field_Mapping__c m : [
            SELECT GuidewireField__c, SalesforceField__c, SalesforceFieldType__c
            FROM Guidewire_Salesforce_Field_Mapping__c
            WHERE SalesforceObject__c = 'Account'
        ]) {
                accountMapping.put(m.GuidewireField__c, m);
            }
            System.debug('Account field mappings loaded: ' + accountMapping.size());
            
            // Prepare
            Account accToUpdate = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
            List<Contact> contactsToUpsert = new List<Contact>();
            
            System.debug('Account fields to update: ' + accToUpdate);
            
            // Loop over AccountContacts in JSON
            for (Object obj : accContacts) {
                Map<String, Object> accContact = (Map<String, Object>) obj;
                System.debug('Processing AccountContact: ' + accContact);
                Map<String, Object> attrs = (Map<String, Object>) accContact.get('attributes');
                System.debug('AccountContact attributes: ' + attrs);
                
                // Extract roles properly (handles both list and single map)
                String roleName;
                Object rolesObj = attrs.get('accountContactRoles');
                System.debug('AccountContact roles object: ' + rolesObj);
                if (rolesObj != null) {
                    if (rolesObj instanceof List<Object>) {
                        List<Object> roleList = (List<Object>)rolesObj;
                        if (!roleList.isEmpty()) {
                            Map<String, Object> roleObj = (Map<String, Object>)roleList[0];
                            roleName = (String)roleObj.get('name');
                        }
                    } else if (rolesObj instanceof Map<String, Object>) {
                        Map<String, Object> roleObj = (Map<String, Object>)rolesObj;
                        roleName = (String)roleObj.get('name');
                    }
                }
                
                
                System.debug('Processing AccountContact with role: ' + roleName);
                if (roleName  == 'AccountHolder') {
                    System.debug('inside AccountHolder block');
                    System.debug('Processing AccountHolder AccountContact, mapping fields to Account' +accountMapping.keySet());
                    // Map AccountContact fields to Account
                    for (String gwField : accountMapping.keySet()) {
                        String path = gwField;
                        if (path.toLowerCase().startsWith('included.accountcontact.attributes.')) {
                            path = path.substring('included.accountcontact.attributes.'.length());
                            System.debug(' Processing path: ' + path.toLowerCase());
                        }
                        Object val = getValueFromPath(attrs, path);
                        //System.debug(' Mapped Value' + val);
                        if (val != null) {
                            accToUpdate.put(accountMapping.get(gwField).SalesforceField__c, val);
                        }
                    }
                } else {
                    // Handle non-AccountHolder AccountContact → Contact
                    // Safely extract id value
                    String gwId;
                    Object idObj = attrs.get('id');
                    System.debug('AccountContact id object: ' + idObj);
                    if (idObj instanceof Map<String, Object>) {
                        System.debug('Inside IF: AccountContact id map: ' + idObj);
                        Map<String, Object> idMap = (Map<String, Object>) idObj;
                        gwId = (String) idMap.get('id');
                    } else if (idObj instanceof String) {
                        System.debug('Inside ELSE: AccountContact id string: ' + idObj);
                        gwId = (String) idObj;
                    }
                    
                    System.debug('AccountContact Guidewire ID: ' + gwId);
                    
                    if (String.isBlank(gwId)) {
                        System.debug('Skipping AccountContact because ID is missing or invalid: ' + attrs);
                        continue;
                    }
                    
                    Contact con = existingContacts.containsKey(gwId)
                        ? existingContacts.get(gwId)
                        : new Contact(AccountId = accountId, Guidewire_ID__c = gwId);
                    
                    System.debug('Processing Contact with Guidewire_ID__c: ' + gwId +' SF Contact :' + con);
                    
                    
                    if (String.isBlank(con.LastName)) con.LastName = 'Unknown';
                    
                    System.debug('Mapping fields to Contact: ' + con);
                    
                    for (String gwField : contactMapping.keySet()) {
                        
                        if (gwField.toLowerCase().startsWith('included.accountcontact.attributes.officialids')) {
                            System.debug('Skipping officialIds path: ' + gwField);
                            continue;
                        }
                        //System.debug(' Original path: ' + path.toLowerCase());

                        String path = gwField;
                        if (path.toLowerCase().startsWith('included.accountcontact.attributes.')) {
                            path = path.substring('included.accountcontact.attributes.'.length());
                            //System.debug(' Processing path: ' + path.toLowerCase());
                        }

                        
                        Object val = getValueFromPath(attrs, path);
                        if (val != null) {
                            // Handle nested object
                            if (val instanceof Map<String, Object>) {
                                Map<String, Object> valMap = (Map<String, Object>) val;
                                if (valMap.containsKey('code')) {
                                    val = valMap.get('code');
                                } else if (valMap.containsKey('displayName')) {
                                    val = valMap.get('displayName');
                                } else {
                                    // fallback: just serialize as string
                                    val = JSON.serialize(valMap);
                                }
                            }
                            con.put(contactMapping.get(gwField).SalesforceField__c, val);
                        }
                    }
                    System.debug('Prepared Contact for upsert: ' + contactsToUpsert.size());
                    contactsToUpsert.add(con);
                }
            }
            
            System.debug('Updating Account fields...');
            update accToUpdate;
            System.debug('Account updated: ' + accToUpdate.Id);
            
            if (!contactsToUpsert.isEmpty()) {
                System.debug('Upserting contacts count: ' + contactsToUpsert.size());
                upsert contactsToUpsert Guidewire_ID__c;
                System.debug('Contacts upsert completed');
            } else {
                System.debug('No contacts to upsert');
            }
            
            System.debug('=== syncAccountAndContacts END for AccountId: ' + accountId + ' ===');
            return 'Account and related contacts updated successfully';
            
        } catch (DmlException dmlEx) {
            System.debug('DML error in syncAccountAndContacts: ' + dmlEx.getMessage());
            GuidewireUtilityClass.logIntegrationError(accountId, 500, 'DML error: ' + dmlEx.getMessage());
            throw new AuraHandledException('Error updating Account or Contacts. Please check Integration Logs.');
        } catch (Exception e) {
            System.debug('General error in syncAccountAndContacts: ' + e.getMessage());
            GuidewireUtilityClass.logIntegrationError(accountId, 500, 'General error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Unexpected error during sync. Please check Integration Logs.');
        }
    }
    
    
    
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
                        //   System.debug(' Processing path: ' + path.toLowerCase());
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
                        System.debug(' Prepared Account record: ' + accRecord);
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