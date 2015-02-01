require_relative '../test_helper'

class ErrorWrappingTest < MiniTest::Unit::TestCase
  TestError = Class.new StandardError

  attr_reader :rpc

  def known_errors
    Thrifter::ErrorWrapping.wrapped
  end

  def setup
    super

    @rpc = Thrifter::RPC.new(:foo, :args)
  end

  def test_wraps_known_exceptions
    app = stub
    app.stubs(:call).with(rpc).raises(known_errors.first)

    middleware = Thrifter::ErrorWrapping.new app

    assert_raises Thrifter::ClientError do
      middleware.call rpc
    end
  end

  def test_can_provid_extras_errors_to_wrap
    app = stub
    app.stubs(:call).with(rpc).raises(TestError)

    middleware = Thrifter::ErrorWrapping.new app, [ TestError ]

    assert_raises Thrifter::ClientError do
      middleware.call rpc
    end
  end

  def test_includes_the_cause_and_message_in_wrapped_message
    app = stub
    app.stubs(:call).with(rpc).raises(TestError.new('testing 123'))

    middleware = Thrifter::ErrorWrapping.new app, [ TestError ]

    error = assert_raises Thrifter::ClientError do
      middleware.call rpc
    end

    assert_match /TestError/, error.message, 'Error class missing'
    assert_match /testing 123/, error.message, 'Message missing'
  end

  def test_wraps_protocol_exception
    assert_includes known_errors, Thrift::ProtocolException
  end

  def test_wraps_transport_exception
    assert_includes known_errors, Thrift::TransportException
  end

  def test_wraps_application_exception
    assert_includes known_errors, Thrift::ApplicationException
  end

  def test_wraps_timeout_error
    assert_includes known_errors, TimeoutError
  end

  def test_wraps_system_call_error
    assert_includes known_errors, SystemCallError
  end
end
