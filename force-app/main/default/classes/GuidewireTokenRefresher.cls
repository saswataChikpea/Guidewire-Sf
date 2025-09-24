/*
-------------------------------------------------------------------------------
 Class Name     : GuidewireTokenRefresher
 Author         : Saswata Banerjee
 Created Date   : 2025-09-12
 Last Modified  : 2025-09-12 
 Description    : Class to schedule GuidewireTokenService.fetchAndStoreToken class. 
 Usage          : Schedule this class using System.schedule() or Setup > Apex Classes
 Dependencies   : GuidewireTokenQueueable
 Notes          : Cron exp has been used via Anon window to run this class every 45 
-------------------------------------------------------------------------------
*/
global with sharing class GuidewireTokenRefresher implements Schedulable {
    global void execute(SchedulableContext sc) {
        GuidewireTokenConfig__c config = GuidewireTokenConfig__c.getOrgDefaults();

        if (config == null || !config.Enable_Scheduler__c) {
            System.debug('GuidewireTokenRefresher: Scheduler disabled by admin. Skipping token refresh.');
            return;
        }

        System.debug('GuidewireTokenRefresher: Scheduler enabled. Refreshing token...');
        System.enqueueJob(new GuidewireTokenQueueable());
    }
}