public with sharing class CreateAccountInGWInvoker {
    @InvocableMethod
    public static void invokeCreateAccountInGW(List<Id> accountIds) {
        GuidewireAccountService.createAccountInGW(accountIds);
    }

}