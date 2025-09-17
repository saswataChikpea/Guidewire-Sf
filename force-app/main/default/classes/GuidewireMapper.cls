public with sharing class GuidewireMapper {

    
    public static List<SObject> upsertRecords(
        String objectName,
        Map<String,String> fieldMap,
        List<Map<String,Object>> records,
        String externalIdField
    ) {
        List<SObject> recordsToUpsert = new List<SObject>();
        List<SObject> upsertedRecords = new List<SObject>();

        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
        if (sObjType == null) {
            throw new AuraHandledException('Invalid object name: ' + objectName);
        }

        for (Map<String,Object> dataMap : records) {
            SObject record = sObjType.newSObject();

            // populate fields using fieldMap
            for (String gwField : fieldMap.keySet()) {
                Object value = getValueFromPath(dataMap, gwField);
                if (value != null) {
                    record.put(fieldMap.get(gwField), value);
                }
            }

            // skip if external ID is missing
            if (record.get(externalIdField) != null) {
                recordsToUpsert.add(record);
            } else {
                System.debug('Skipping record, ' + externalIdField + ' missing');
            }
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert ;
            upsertedRecords = recordsToUpsert;
        }

        return upsertedRecords;
    }

    // nested path utility (dot notation)
    private static Object getValueFromPath(Map<String,Object> mapData, String path) {
        String[] parts = path.split('\\.');
        Object current = mapData;

        for (String p : parts) {
            if (current instanceof Map<String,Object>) {
                Map<String,Object> curMap = (Map<String,Object>) current;
                if (curMap.containsKey(p)) {
                    current = curMap.get(p);
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
        return current;
    }
}
