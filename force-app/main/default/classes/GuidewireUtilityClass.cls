/*
-------------------------------------------------------------------------------
 Class Name     : GuidewireUtilityClass
 Author         : Subhadip Sarkar
 Created Date   : 2025-09-18
 Last Modified  : 2025-09-18 
 Description    : This class uses a static method to log integration errors in a custom object.
 Usage          : 
 Dependencies   : 
 Notes          : 
-------------------------------------------------------------------------------
*/
public with sharing class GuidewireUtilityClass {

        public static void logIntegrationError(String recordId, Integer statusCode, String message) {
            Integration_Log__c log = new Integration_Log__c();
            log.Name = 'Guidewire Integration ';
            log.Related_Record_Id__c = recordId;
            log.Status_Code__c = statusCode;
            log.Message__c = message;
            //log.Salesforce_Object__c = sfDetails;
            insert log;
        }
    
}