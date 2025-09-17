/*
-------------------------------------------------------------------------------
 Class Name     : GuidewireTokenQueueable
 Author         : Saswata Banerjee
 Created Date   : 2025-09-12
 Last Modified  : 2025-09-12 
 Description    : Queueable class to call GuidewireTokenService and refresh token.
 Usage          : Enqueued from GuidewireTokenRefresher or other Apex
 Dependencies   : GuidewireTokenService
 Notes          : Implements Database.AllowsCallouts to allow HTTP callouts.
-------------------------------------------------------------------------------
*/
public class GuidewireTokenQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        try {
            System.debug('GuidewireTokenQueueable executing at ' + System.now());
            GuidewireTokenService.fetchAndStoreToken();
        } catch (Exception ex) {
            System.debug('Error refreshing token: ' + ex.getMessage());
        }
    }
}
