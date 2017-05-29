require_relative '../test_helper'

class RpcMetricsTest < MiniTest::Unit::TestCase
  attr_reader :rpc

  def setup
    super

    @rpc = Thrifter::RPC.new(:foo, :args)
  end

  def test_happy_path
    app = stub
    app.stubs(:call).with(rpc)

    statsd = mock
    statsd.expects(:time).with("rpc.#{rpc.name}.latency").yields.returns(:response)
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.success")

    middleware = Thrifter::RpcMetrics.new app, statsd
    result = middleware.call rpc

    assert :response == result, 'Return value incorrect'
  end

  def test_counts_unknown_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException.new(
      Thrift::TransportException::UNKNOWN
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.transport.unknown")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_not_open_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException.new(
      Thrift::TransportException::NOT_OPEN
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.transport.not_open")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_already_open_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException.new(
      Thrift::TransportException::ALREADY_OPEN
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.transport.already_open")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_timed_out_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException.new(
      Thrift::TransportException::TIMED_OUT
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.transport.timeout")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_eof_transport_exceptions_and_reraises
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::TransportException.new(
      Thrift::TransportException::END_OF_FILE
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.transport.eof")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::TransportException do
      middleware.call rpc
    end
  end

  def test_counts_unknown_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::UNKNOWN
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.unknown")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_invalid_data_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::INVALID_DATA
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.invalid_data")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_negative_size_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::NEGATIVE_SIZE
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.negative_size")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_size_limit_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::SIZE_LIMIT
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.size_limit")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_bad_version_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::BAD_VERSION
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.bad_version")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_not_implemented_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::NOT_IMPLEMENTED
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.not_implemented")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_depth_limit_protocol_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ProtocolException.new(
      Thrift::ProtocolException::DEPTH_LIMIT
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.protocol.depth_limit")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ProtocolException do
      middleware.call rpc
    end
  end

  def test_counts_unknown_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::UNKNOWN
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.unknown")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_unknown_method_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::UNKNOWN_METHOD
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.unknown_method")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_invalid_message_type_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::INVALID_MESSAGE_TYPE
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.invalid_message_type")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_wrong_method_name_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::WRONG_METHOD_NAME
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.wrong_method_name")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_bad_sequence_id_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::BAD_SEQUENCE_ID
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.bad_sequence_id")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_missing_result_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::MISSING_RESULT
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.missing_result")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_internal_error_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::INTERNAL_ERROR
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.internal_error")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_protocol_error_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::PROTOCOL_ERROR
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.protocol_error")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_invalid_transform_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::INVALID_TRANSFORM
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.invalid_transform")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_invalid_protocol_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::INVALID_PROTOCOL
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.invalid_protocol")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_unsupported_client_type_application_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(Thrift::ApplicationException.new(
      Thrift::ApplicationException::UNSUPPORTED_CLIENT_TYPE
    ))

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.application.unsupported_client_type")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Thrift::ApplicationException do
      middleware.call rpc
    end
  end

  def test_counts_timeouts
    app = stub
    app.stubs(:call).with(rpc).raises(Timeout::Error)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.timeout")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises Timeout::Error do
      middleware.call rpc
    end
  end

  def test_counts_other_errors
    app = stub
    app.stubs(:call).with(rpc).raises(StandardError)

    statsd = mock
    statsd.expects(:time).yields
    statsd.expects(:increment).with("rpc.#{rpc.name}.error.other")
    statsd.expects(:increment).with("rpc.#{rpc.name}.outgoing")
    statsd.expects(:increment).with("rpc.#{rpc.name}.error")

    middleware = Thrifter::RpcMetrics.new app, statsd

    assert_raises StandardError do
      middleware.call rpc
    end
  end
end
