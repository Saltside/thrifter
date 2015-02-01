require_relative './test_helper'

class ValidationMiddlewareTest < MiniTest::Unit::TestCase
  attr_reader :rpc, :invalid_struct, :valid_struct

  def setup
    super

    @rpc = Thrifter::RPC.new :echo

    @invalid_struct = TestMessage.new
    @valid_struct = TestMessage.new message: 'testing'
  end

  def test_fails_if_args_contains_invalid_structs
    rpc.args = [ invalid_struct ]

    client = stub call: valid_struct

    middleware = Thrifter::ValidationMiddleware.new client

    assert_raises Thrifter::ValidationError do
      middleware.call rpc
    end
  end

  def test_does_not_validate_primitive_request_values
    rpc.args = [ 1, 2, 3 ]

    client = stub call: valid_struct

    middleware = Thrifter::ValidationMiddleware.new client

    assert_equal valid_struct, middleware.call(rpc)
  end

  def test_fails_if_repsonse_contains_invalid_structs
    rpc.args = [ valid_struct ]

    client = stub call: invalid_struct

    middleware = Thrifter::ValidationMiddleware.new client

    assert_raises Thrifter::ValidationError do
      middleware.call rpc
    end
  end

  def test_does_not_validate_primitive_response_values
    rpc.args = [ valid_struct ]

    client = stub call: [ 1, 2 ]

    middleware = Thrifter::ValidationMiddleware.new client
    assert_equal [ 1,2 ], middleware.call(rpc)
  end
end
