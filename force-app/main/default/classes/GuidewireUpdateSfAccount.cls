/*
-------------------------------------------------------------------------------
 Class Name     : GuidewireUpdateSfAccount
 Author         : Saswata Banerjee
 Created Date   : 2025-09-22
 Last Modified  : 2025-09-22 
 Description    : This class fetches account data from Guidewire API and updates it into Salesforce.
 Usage          : Used by GuidewireUpdateSfAccount LWC component.
 Dependencies   : 
 Notes          : 
-------------------------------------------------------------------------------
*/
public with sharing class GuidewireUpdateSfAccount {

    @AuraEnabled(cacheable=false)
    public static String syncAccount(String recordIdOrDummy) {
        System.debug('Starting Guidewire account sync for recordIdOrDummy: ' + recordIdOrDummy);
        // Fixed URL for now
        String url = 'callout:GuidewireMockNC/pc/rest/account/v1/accounts/' + recordIdOrDummy;
        //String url = 'https://your-guidewire-api.com/accounts/12345';

        try {

            System.debug('Making HTTP GET request to Guidewire API at: ' + url);
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            System.debug('endpoint set: ' + url);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');

            Http http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('Guidewire response code: ' + res.getStatusCode());

            if (res.getStatusCode() == 200) {
                String gwJson = res.getBody();
                
              //  System.debug('Received Guidewire response: ' + gwJson);
                List<Account> upsertedAccounts = GuidewireAccountService.upsertAccountsFromJson(gwJson);

                return ' Updated ' + upsertedAccounts.size() + ' account(s) successfully.';
            } else {
                // log error
                GuidewireUtilityClass.logIntegrationError(
                    recordIdOrDummy,
                    res.getStatusCode(),
                    'Guidewire API error at ' + url + ' : ' + res.getStatus() + ' - ' + res.getBody()
                );
                throw new AuraHandledException('Guidewire API error. Please check Integration Logs.');
            }

        } catch (Exception e) {
            // log error
            GuidewireUtilityClass.logIntegrationError(
                recordIdOrDummy,
                123,
                'Error during Guidewire sync at ' + url + ' : ' + e.getMessage() + 
                ' | Stack: ' + e.getStackTraceString()
            );
            throw new AuraHandledException('Error during Guidewire sync. Please check Integration Logs.');
        }
    }
}