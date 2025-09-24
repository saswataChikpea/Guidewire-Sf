@isTest
public with sharing class GuidewireUpdateSfAccountTest {

    // Mock HTTP response for Guidewire API (success)
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"included":[{"attributes":{"id":"GW123","Name":"Test Account"}}]}');
            return res;
        }
    }

    // Mock HTTP response for Guidewire API (error)
    private class MockHttpErrorResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    // Mock HTTP response that throws exception
    private class MockHttpExceptionGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    @isTest
    static void testSyncAccount_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        String result = GuidewireUpdateSfAccount.syncAccount('GW123');
        Test.stopTest();
        System.assert(result.contains('Updated'), 'Should return success message');
    }

    @isTest
    static void testSyncAccount_ApiError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponseGenerator());
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            GuidewireUpdateSfAccount.syncAccount('GW123');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('error'), 'Exception message: ' + e.getMessage());
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AuraHandledException should be thrown');
    }

    @isTest
    static void testSyncAccount_Exception() {
        Test.setMock(HttpCalloutMock.class, new MockHttpExceptionGenerator());
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            GuidewireUpdateSfAccount.syncAccount('GW123');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Error'), 'Exception message: ' + e.getMessage());
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'AuraHandledException should be thrown');
    }
}