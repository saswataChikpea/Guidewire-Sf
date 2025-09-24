@isTest
private class HelloWorldTest {
    @isTest
    static void testHelloWorld() {
        HelloWorld hw = new HelloWorld();
        String result = hw.sayHello();
        System.assertEquals('Hello, World!', result);
    }
}