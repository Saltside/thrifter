require_relative './test_helper'

class StatsdMiddlewareTest < MiniTest::Unit::TestCase
  attr_reader :rpc

  def setup
    super

    @rpc = Thrifter::RPC.new(:foo, :args)
  end

  def test_times_each_rpc
    app = stub
    app.stubs(:call).with(rpc)

    statsd = mock
    statsd.expects(:time).with(rpc.name).yields.returns(:response)

    middleware = Thrifter::StatsdMiddleware.new app, statsd
    result = middleware.call rpc

    assert :response == result, 'Return value incorrect'
  end

  def test_counts_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('errors.transport')

    middleware = Thrifter::StatsdMiddleware.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('errors.protocol')

    middleware = Thrifter::StatsdMiddleware.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('errors.application')

    middleware = Thrifter::StatsdMiddleware.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_timeouts
    app = stub
    app.stubs(:call).with(rpc).raises(Timeout::Error)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('errors.timeout')

    middleware = Thrifter::StatsdMiddleware.new app, statsd

    assert_raises Timeout::Error do
      middleware.call rpc
    end
  end

  def test_counts_other_errors
    app = stub
    app.stubs(:call).with(rpc).raises(StandardError)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with('errors.other')

    middleware = Thrifter::StatsdMiddleware.new app, statsd

    assert_raises StandardError do
      middleware.call rpc
    end
  end
end
