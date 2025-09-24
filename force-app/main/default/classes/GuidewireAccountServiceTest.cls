@IsTest
public class GuidewireAccountServiceTest {

    // ---------------- MOCK CLASSES ----------------
    private class GuidewireSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('PATCH', req.getMethod(), 'HTTP method should be PATCH');
            System.assert(req.getEndpoint().contains('/accounts/'), 'Endpoint should contain /accounts/');

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message":"Account updated successfully"}');
            return res;
        }
    }

    private class GuidewireFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid request"}');
            return res;
        }
    }

    // ---------------- HELPER METHOD ----------------
    private static void insertFieldMappings() {
        List<Guidewire_Salesforce_Field_Mapping__c> mappings = new List<Guidewire_Salesforce_Field_Mapping__c>{
            new Guidewire_Salesforce_Field_Mapping__c(
                SalesforceObject__c = 'Account',
                SalesforceField__c = 'Name',
                SalesforceFieldType__c = 'String',
                GuideWireField__c = 'included.account.name'
            ),
            new Guidewire_Salesforce_Field_Mapping__c(
                SalesforceObject__c = 'Account',
                SalesforceField__c = 'GW_Do_Not_Destroy__c',
                SalesforceFieldType__c = 'Boolean',
                GuideWireField__c = 'included.account.isActive'
            ),
            new Guidewire_Salesforce_Field_Mapping__c(
                SalesforceObject__c = 'Account',
                SalesforceField__c = 'GW_Origination_Date__c',
                SalesforceFieldType__c = 'Date',
                GuideWireField__c = 'included.account.originationDate'
            ),
            new Guidewire_Salesforce_Field_Mapping__c(
                SalesforceObject__c = 'Account',
                SalesforceField__c = 'Guidewire_Created_Date__c',
                SalesforceFieldType__c = 'DateTime',
                GuideWireField__c = 'included.account.createdDate'
            )
        };
        insert mappings;
    }

    // ---------------- TEST METHODS ----------------

    @IsTest
    static void testUpdateAccountSuccess() {
        insertFieldMappings(); // Ensure mappings exist

        Account acc = new Account(
            Name = 'Test Account',
            AccountNumber = '12345',
            GW_Do_Not_Destroy__c = false,
            GW_Origination_Date__c = Date.today(),
            Guidewire_Created_Date__c = System.now()
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class, new GuidewireSuccessMock());

        Test.startTest();
        GuidewireAccountService.updateAccountInGW(new List<Id>{acc.Id});
        CreateAccountInGWInvoker.invokeCreateAccountInGW(new List<Id>{acc.Id});
        Test.stopTest();

        // Verify JSON body got built correctly
        String body = GuidewireJsonBuilder.buildBody(acc, 'Account');
        System.assert(body.contains('name'), 'JSON should contain account name');
        System.assert(body.contains('isActive'), 'JSON should contain boolean field');
        System.assert(body.contains('originationDate'), 'JSON should contain date field');
        System.assert(body.contains('createdDate'), 'JSON should contain datetime field');
    }

    @IsTest
    static void testUpdateAccountFailure() {
        insertFieldMappings();

        Account acc = new Account(
            Name = 'Test Account',
            AccountNumber = '12345',
            GW_Do_Not_Destroy__c = false,
            GW_Origination_Date__c = Date.today(),
            Guidewire_Created_Date__c = System.now()
        );
        insert acc;

        Test.setMock(HttpCalloutMock.class, new GuidewireFailureMock());

        Test.startTest();
        GuidewireAccountService.updateAccountInGW(new List<Id>{acc.Id});
        CreateAccountInGWInvoker.invokeCreateAccountInGW(new List<Id>{acc.Id});

        Test.stopTest();

        
    }

    @IsTest
    static void testUpdateAccountWithEmptyList() {
        Test.startTest();
        GuidewireAccountService.updateAccountInGW(new List<Id>());
        CreateAccountInGWInvoker.invokeCreateAccountInGW(new List<Id>());
        Test.stopTest();
    }

    
}