public class GuidewireJsonBuilder {
    
    /**
     * Build JSON request body dynamically using the mapping object.
     *
     * @param record     The Salesforce SObject record (Account, Policy, etc.)
     * @param objectName The Salesforce object API name (e.g., 'Account')
     * @return           JSON string representing Guidewire body
     */
    public static String buildBody(SObject record, String objectName) {
        // Step 1: Query mapping metadata
        List<Guidewire_Salesforce_Field_Mapping__c> mappings = [
            SELECT GuideWireField__c, SalesforceField__c, SalesforceFieldType__c
            FROM Guidewire_Salesforce_Field_Mapping__c
            WHERE SalesforceObject__c = :objectName
        ];
        System.debug(record.Id);
        System.debug(objectName);

        // Step 2: Build root JSON structure
        Map<String, Object> gwBody = new Map<String, Object>();

        for (Guidewire_Salesforce_Field_Mapping__c mapRec : mappings) {
            Object fieldValue = record.get(mapRec.SalesforceField__c);

            if (fieldValue != null) {
                // Convert based on type
                if (mapRec.SalesforceFieldType__c == 'Boolean') {
                    fieldValue = (Boolean)fieldValue;
                } else if (mapRec.SalesforceFieldType__c == 'Date') {
                    fieldValue = ((Date)fieldValue).format();
                } else if (mapRec.SalesforceFieldType__c == 'DateTime') {
                    fieldValue = ((Datetime)fieldValue).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                }

                // Build nested structure
                addFieldToBody(gwBody, mapRec.GuideWireField__c, fieldValue);
            }
        }

        // Step 3: Return JSON
        System.debug('Guidewire JSON Body: ' + JSON.serialize(gwBody));
        return JSON.serialize(gwBody);
    }

    private static void addFieldToBody(Map<String, Object> rootMap, String gwFieldPath, Object fieldValue) {
    // Step 1: Normalize root
    if (gwFieldPath.startsWith('included.account.')) {
        gwFieldPath = 'Data.' + gwFieldPath.substring('included.account.'.length());
    }
    // Split path and build nested map
    List<String> parts = gwFieldPath.split('\\.');
    Map<String, Object> currentMap = rootMap;

    for (Integer i = 0; i < parts.size(); i++) {
        String key = parts[i];
        Boolean isLast = (i == parts.size() - 1);

        if (isLast) {
            currentMap.put(toCamelCase(key), fieldValue);
        } else {
            Object existing = currentMap.get(toCamelCase(key));
            if (existing == null) {
                Map<String, Object> newMap = new Map<String, Object>();
                currentMap.put(toCamelCase(key), newMap);
                currentMap = newMap;
            } else {
                currentMap = (Map<String, Object>)existing;
            }
        }
    }
    }

    private static String toCamelCase(String input) {
        if (String.isBlank(input)) return input;
        return input.substring(0,1).toLowerCase() + input.substring(1);
    }

}