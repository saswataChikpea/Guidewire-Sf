@isTest
public with sharing class GuidewireTokenRefresherTest {

    @isTest
    static void testScheduler_Enabled() {
        // Simulate custom setting enabled
        GuidewireTokenConfig__c config = new GuidewireTokenConfig__c(Enable_Scheduler__c = true);
        insert config;

        Test.startTest();
        GuidewireTokenRefresher refresher = new GuidewireTokenRefresher();
        refresher.execute(null);
        Test.stopTest();

        // Check that a job was enqueued
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'Queueable job should be enqueued');
    }

    @isTest
    static void testScheduler_Disabled() {
        // Simulate custom setting disabled
        GuidewireTokenConfig__c config = new GuidewireTokenConfig__c(Enable_Scheduler__c = false);
        insert config;

        Test.startTest();
        GuidewireTokenRefresher refresher = new GuidewireTokenRefresher();
        refresher.execute(null);
        Test.stopTest();

        // No queueable job should be enqueued
        System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'No queueable job should be enqueued');
    }

    @isTest
    static void testScheduler_NoConfig() {
        // No config inserted

        Test.startTest();
        GuidewireTokenRefresher refresher = new GuidewireTokenRefresher();
        refresher.execute(null);
        Test.stopTest();

        // No queueable job should be enqueued
        System.assertEquals(0, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable'], 'No queueable job should be enqueued');
    }
}