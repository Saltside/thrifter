require_relative '../test_helper'

class RetryTest < MiniTest::Unit::TestCase
  JunkError = Class.new StandardError
  KnownError = Class.new StandardError

  class RetryClient < Thrifter.build(TestService::Client)
    include Thrifter::Retry

    config.uri = 'tcp://localhost:9090'

    # This is enough to get around thrift's networking objects and focus
    # on stubbing the actual thrift client.
    config.transport = FakeTransport
  end

  class TestStatsd
    attr_reader :counters

    def initialize
      @counters = [ ]
    end

    def increment(counter)
      @counters << counter
    end

    def time(*args)
      yield
    end

    def gauge(*)

    end
  end

  attr_reader :statsd

  def known_errors
    Thrifter::Retry::DEFAULT_RETRIABLE_ERRORS
  end

  def setup
    super
    @statsd = TestStatsd.new

    RetryClient.configure do |config|
      config.statsd = statsd
    end
  end

  def test_does_not_retry_on_unexpected_errors
    thrift_client = mock
    thrift_client.expects(:echo).with(:request).raises(JunkError)
    TestService::Client.stubs(:new).returns(thrift_client)

    client = RetryClient.new

    assert_raises JunkError do
      client.with_retry({ tries: 2, interval: 0.01 }).echo(:request)
    end
  end

  def test_retries_on_known_exceptions
    thrift_client = mock
    retries = sequence(:retries)
    thrift_client.expects(:echo).with(:request).in_sequence(retries).raises(known_errors.sample)
    thrift_client.expects(:echo).with(:request).in_sequence(retries).returns(:response)
    TestService::Client.stubs(:new).returns(thrift_client)

    client = RetryClient.new

    result = client.with_retry({ tries: 2, interval: 0.01 }).echo(:request)

    assert :response == result, 'return value incorrect'

    counters = statsd.counters.count do |item|
      item == 'rpc.echo.retry'
    end

    assert_equal 1, counters, 'Retry not counted'
  end

  def test_retries_on_exceptions_specified_explicitly
    thrift_client = mock
    retries = sequence(:retries)
    thrift_client.expects(:echo).with(:request).in_sequence(retries).raises(KnownError)
    thrift_client.expects(:echo).with(:request).in_sequence(retries).returns(:response)
    TestService::Client.stubs(:new).returns(thrift_client)

    client = RetryClient.new

    result = client.with_retry({ tries: 2, interval: 0.01, retriable: KnownError }).echo(:request)

    assert :response == result, 'return value incorrect'
  end

  def test_retries_on_exceptions_specified_in_array
    thrift_client = mock
    retries = sequence(:retries)
    thrift_client.expects(:echo).with(:request).in_sequence(retries).raises(KnownError)
    thrift_client.expects(:echo).with(:request).in_sequence(retries).returns(:response)
    TestService::Client.stubs(:new).returns(thrift_client)

    client = RetryClient.new

    result = client.with_retry({ tries: 2, interval: 0.01, retriable: [ KnownError ] }).echo(:request)

    assert :response == result, 'return value incorrect'
  end

  def test_fails_if_does_not_respond_successfully
    err = known_errors.sample

    thrift_client = mock
    thrift_client.expects(:echo).with(:request).raises(err).times(5)
    TestService::Client.stubs(:new).returns(thrift_client)

    client = RetryClient.new

    error = assert_raises Thrifter::RetryError do
      client.with_retry({ tries: 5, interval: 0.01 }).echo(:request)
    end

    assert_match /5/, error.message, 'Error not descriptive'
    assert_match /echo/, error.message, 'Error not descriptive'
    assert_match /#{err.to_s}/, error.message, 'Missing error details'

    counters = statsd.counters.count do |item|
      item == 'rpc.echo.retry'
    end

    assert_equal 5, counters, 'Retry not counted'
  end

  def test_retries_on_application_exception
    assert_includes known_errors, Thrift::ApplicationException
  end

  def test_retries_on_protocol_exception
    assert_includes known_errors, Thrift::ProtocolException
  end

  def test_retries_on_transport_exception
    assert_includes known_errors, Thrift::TransportException
  end

  def test_retries_on_timeout_error
    assert_includes known_errors, Timeout::Error
  end

  def test_retries_on_wrapped_client_error
    assert_includes known_errors, Thrifter::ClientError
  end

  def test_retries_on_econrefused
    assert_includes known_errors, Errno::ECONNREFUSED
  end

  def test_retries_on_eaddrnotavail
    assert_includes known_errors, Errno::EADDRNOTAVAIL
  end

  def test_retries_on_ehostdown
    assert_includes known_errors, Errno::EHOSTDOWN
  end

  def test_retries_on_ehostunreach
    assert_includes known_errors, Errno::EHOSTUNREACH
  end

  def test_retries_on_etimedout
    assert_includes known_errors, Errno::ETIMEDOUT
  end

  def test_works_with_block_form
    thrift_client = mock
    thrift_client.expects(:echo).with(:request).returns(:response)
    TestService::Client.stubs(:new).returns(thrift_client)

    client = RetryClient.new

    client.with_retry do |with_retry|
      with_retry.echo :request
    end
  end

  def test_fails_if_given_rpc_name
    client = RetryClient.new

    assert_raises NoMethodError do
      client.with_retry.foo
    end
  end
end
