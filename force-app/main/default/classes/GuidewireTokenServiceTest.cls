@isTest
public with sharing class GuidewireTokenServiceTest {

    // Mock HTTP response for token fetch
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"testtoken","token_type":"Bearer","expires_in":3600}');
            return res;
        }
    }

    @isTest
    static void testFetchAndStoreToken_Insert() {
        // Ensure no token exists (DML before callout)
        delete [SELECT Id FROM Authorization_Token_Setup__c];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Authorization_Token_Setup__c token = GuidewireTokenService.fetchAndStoreToken();
        Test.stopTest();

        System.assertEquals('testtoken', token.Access_Token__c);
        System.assertEquals('Bearer', token.Token_Type__c);
        System.assert(token.Expires_At__c > System.now());
    }

    @isTest
    static void testFetchAndStoreToken_Update() {
        // Insert an existing token (DML before callout)
        Authorization_Token_Setup__c existing = new Authorization_Token_Setup__c(
            Access_Token__c = 'oldtoken',
            Token_Type__c = 'Old',
            Expires_At__c = System.now()
        );
        insert existing;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Authorization_Token_Setup__c token = GuidewireTokenService.fetchAndStoreToken();
        Test.stopTest();

        System.assertEquals('testtoken', token.Access_Token__c);
        System.assertEquals('Bearer', token.Token_Type__c);
        System.assert(token.Expires_At__c > System.now());
    }

    @isTest
    static void testRefreshTokenFromFlow_AutoEnabled() {
        // Simulate custom setting enabled (DML before callout)
        GuidewireTokenConfig__c config = new GuidewireTokenConfig__c(Enable_Scheduler__c = true);
        insert config;

        Test.startTest();
        List<String> result = GuidewireTokenService.refreshTokenFromFlow(new List<String>{'dummy'});
        Test.stopTest();

        System.assertEquals('Auto Token refresh enabled by admin. Ask your admin to disable it and then try again.', result[0]);
    }

    @isTest
    static void testRefreshTokenFromFlow_Manual() {
        // Simulate custom setting disabled (DML before callout)
        GuidewireTokenConfig__c config = new GuidewireTokenConfig__c(Enable_Scheduler__c = false);
        insert config;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        List<String> result = GuidewireTokenService.refreshTokenFromFlow(new List<String>{'dummy'});
        Test.stopTest();

        System.assertEquals('Guidewire token refreshed successfully', result[0]);
    }
}