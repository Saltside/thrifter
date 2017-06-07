require_relative '../test_helper'

class ClientMetricsTest < MiniTest::Unit::TestCase
  attr_reader :rpc

  def setup
    super

    @rpc = Thrifter::RPC.new(:foo, :args)
  end

  def test_happy_path_calls
    app = stub
    app.stubs(:call).with(rpc)

    statsd = mock
    statsd.expects(:time).with('rpc.latency').yields.returns(:response)
    statsd.expects(:increment).with('rpc.success')
    statsd.expects(:increment).with('rpc.outgoing')

    middleware = Thrifter::ClientMetrics.new app, statsd
    result = middleware.call rpc

    assert :response == result, 'Return value incorrect'
  end

  def test_counts_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('rpc.outgoing')
    statsd.expects(:increment).with('rpc.error.transport')
    statsd.expects(:increment).with('rpc.error')

    middleware = Thrifter::ClientMetrics.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('rpc.outgoing')
    statsd.expects(:increment).with('rpc.error.protocol')
    statsd.expects(:increment).with('rpc.error')

    middleware = Thrifter::ClientMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('rpc.outgoing')
    statsd.expects(:increment).with('rpc.error.application')
    statsd.expects(:increment).with('rpc.error')

    middleware = Thrifter::ClientMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_timeouts
    app = stub
    app.stubs(:call).with(rpc).raises(Timeout::Error)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('rpc.outgoing')
    statsd.expects(:increment).with('rpc.error.timeout')
    statsd.expects(:increment).with('rpc.error')

    middleware = Thrifter::ClientMetrics.new app, statsd

    assert_raises Timeout::Error do
      middleware.call rpc
    end
  end

  def test_counts_retry_failures
    app = stub
    app.stubs(:call).with(rpc).raises(Thrifter::RetryError.new(1, 'echo', StandardError.new))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.error")
    statsd.expects(:increment).with("rpc.outgoing")
    statsd.expects(:increment).with("rpc.error.retry")

    middleware = Thrifter::ClientMetrics.new app, statsd

    assert_raises Thrifter::RetryError  do
      middleware.call rpc
    end
  end

  def test_counts_other_errors
    app = stub
    app.stubs(:call).with(rpc).raises(StandardError)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('rpc.outgoing')
    statsd.expects(:increment).with('rpc.error.other')
    statsd.expects(:increment).with('rpc.error')

    middleware = Thrifter::ClientMetrics.new app, statsd

    assert_raises StandardError do
      middleware.call rpc
    end
  end
end
