/*
-------------------------------------------------------------------------------
 Class Name     : GuidewireTokenService
 Author         : Saswata Banerjee
 Created Date   : 2025-09-12
 Last Modified  : 2025-09-12 
 Description    :  Class to handle fetching and storing Guidewire API tokens.
                   Also exposes an Invocable Method so Flow can refresh the token.
 Usage          : Called from Apex, Flow, or manually to refresh the token.
 Dependencies   : GuidewireTokenConfig__c custom setting
 Notes          : Reads the Enable_Scheduler__c checkbox from custom setting
-------------------------------------------------------------------------------
*/
public with sharing class GuidewireTokenService {

    
    public static Authorization_Token_Setup__c fetchAndStoreToken() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:GuidewireMockNC/login'); // Named Credential
        req.setMethod('GET');

        HttpResponse res = http.send(req);
        if(res.getStatusCode() == 200) {
            Map<String,Object> payload = 
                (Map<String,Object>) JSON.deserializeUntyped(res.getBody());

            String accessToken = (String) payload.get('access_token');
            String tokenType = (String) payload.get('token_type');
            Integer expiresIn = (Integer) payload.get('expires_in');

            // Query your existing record
            Authorization_Token_Setup__c tokenRecord;
            List<Authorization_Token_Setup__c> existing = [
                SELECT Id, Access_Token__c, Token_Type__c, Expires_At__c
                FROM Authorization_Token_Setup__c
                ORDER BY Expires_At__c DESC
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                tokenRecord = existing[0];
                tokenRecord.Access_Token__c = accessToken;
                tokenRecord.Token_Type__c = tokenType;
                tokenRecord.Expires_At__c = System.now().addSeconds(expiresIn);
                update tokenRecord;
            } else {
                // if Token exist, create it
                tokenRecord = new Authorization_Token_Setup__c(
                    
                    Access_Token__c = accessToken,
                    Token_Type__c = tokenType,
                    Expires_At__c = System.now().addSeconds(expiresIn)
                );
                insert tokenRecord;
            }

            System.debug('Updated token record: ' + tokenRecord);
            return tokenRecord;
        } else {
            throw new CalloutException('Failed to get token: ' + res.getBody());
        }
    }

    // Invocable Method for Flow, with custom setting check
    @InvocableMethod(label='Refresh Guidewire Token' description='Manually refresh the Guidewire token from Flow')
    public static List<String> refreshTokenFromFlow(List<String> dummy) {

        // read custom setting GuidewireTokenConfig__c
        GuidewireTokenConfig__c config = GuidewireTokenConfig__c.getOrgDefaults();

        // if config missing or disabled, just return message without calling endpoint
        if (config == null || config.Enable_Scheduler__c) {
            return new List<String>{'Auto Token refresh enabled by admin. Ask your admin to disable it and then try again.'};
        }

        // otherwise fetch and store token
        fetchAndStoreToken();
        return new List<String>{'Guidewire token refreshed successfully'};
    }

    
}