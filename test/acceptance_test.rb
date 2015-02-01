require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  SimulatedError = Class.new StandardError

  class TestClient < TestService::Client
    def echo(message)
      message
    end
  end

  class BrokenTestClient < TestService::Client
    def echo(message)
      fail SimulatedError
    end
  end

  attr_reader :uri

  def setup
    super

    @uri = URI('tcp://localhost:9090')
  end

  def test_defaults_to_framed_transport
    client = Thrifter.build TestClient
    assert_equal Thrift::FramedTransport, client.config.transport
  end

  def test_defaults_to_binary_protocol
    client = Thrifter.build TestClient
    assert_equal Thrift::BinaryProtocol, client.config.protocol
  end

  def test_defaults_to_12_connections
    client = Thrifter.build TestClient
    assert_equal 12, client.config.pool_size
  end

  def test_has_reasonable_default_pool_timeout
    client = Thrifter.build TestClient
    assert_equal 0.1, client.config.pool_timeout
  end

  def test_has_reasonable_default_rpc_timeout
    client = Thrifter.build TestClient
    assert_equal 0.3, client.config.rpc_timeout
  end

  def test_defaults_to_null_statd
    client = Thrifter.build TestClient
    assert_instance_of Thrifter::NullStatsd, client.config.statsd
  end

  def test_configuration_has_a_block_form
    client = Thrifter.build TestClient

    client.configure do |config|
      config.transport = :via_block
    end

    assert :via_block == client.config.transport, 'Block form incorrect'
  end

  def test_fails_if_uri_not_configured
    client = Thrifter.build TestClient do
      config.uri = nil
    end

    error = assert_raises ArgumentError do
      client.new
    end

    assert_match /uri/, error.message
  end

  def test_fails_if_uri_does_not_contain_port
    client = Thrifter.build TestClient do
      config.uri = 'tcp://localhost'
    end

    error = assert_raises ArgumentError do
      client.new
    end

    assert_match /port/, error.message
  end

  def test_pool_options_are_forwarded
    client = Thrifter.build TestClient do
      config.uri = 'http://localhost:9090'
      config.pool_size = 50
      config.pool_timeout = 75
    end

    ConnectionPool.expects(:new).with(size: 50, timeout: 75)

    client.new
  end

  # NOTE: This test is quite unfortunate, but there does not seem to be a good
  # way to simulate the 4 objects required to get a Thrift::Client instance
  # off the ground. The monkey tests will ensure the final product can communicate
  # to a server correctly. For now, just test the things are built in a sane way.
  def test_builds_thrift_object_chain_correctly
    test_message = TestMessage.new message: 'testing 123'

    client = Thrifter.build TestClient
    client.config.uri = uri

    socket, transport, protocol = stub, stub(open: nil, close: nil), stub

    Thrift::Socket.expects(:new).
      with(uri.host, uri.port, client.config.rpc_timeout).
      returns(socket)

    client.config.transport.expects(:new).
      with(socket).
      returns(transport)

    client.config.protocol.expects(:new).
      with(transport).
      returns(protocol)

    thrift_client = stub
    thrift_client.expects(:echo).
      with(test_message).
      returns(test_message)

    TestClient.expects(:new).with(protocol).returns(thrift_client)

    thrifter = client.new

    # connection pool is built lazily, so an RPC must be made to
    # trigger the build
    thrifter.echo test_message
  end

  def test_middleware_can_be_configured
    test_message = TestMessage.new message: '123'

    client = Thrifter.build TestClient
    client.config.uri = uri
    client.config.transport = FakeTransport

    test_middleware = Class.new do
      include Concord.new(:app, :salt)

      def call(rpc)
        rpc.args.first.message = salt + rpc.args.first.message
        app.call rpc
      end
    end

    client.use test_middleware, 'testing'

    thrifter = client.new
    result = thrifter.echo test_message
    assert_match /testing/, result.message, 'Middleware not called'
  end

  def test_close_the_transport_on_successful_rpc
    transport = mock
    client = Thrifter.build TestClient
    client.config.uri = uri
    client.config.transport.stubs(:new).returns(transport)

    transport.expects(:open)
    transport.expects(:close)

    thrifter = client.new
    thrifter.echo message
  end

  def test_close_the_transport_if_client_fails
    transport = mock
    client = Thrifter.build BrokenTestClient
    client.config.uri = uri
    client.config.transport.stubs(:new).returns(transport)

    transport.expects(:open)
    transport.expects(:close)

    thrifter = client.new

    assert_raises SimulatedError do
      thrifter.echo message
    end
  end
end
