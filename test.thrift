struct TestMessage  {
  1: required string message
}

service TestService {
  TestMessage echo(1: TestMessage message)
  oneway void onewayEcho(1: TestMessage message)
}
