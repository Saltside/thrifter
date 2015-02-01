require_relative './test_helper'

class PingTest < MiniTest::Unit::TestCase
  def test_returns_false_if_anything_goes_wrong
    down_class = Class.new do
      include Thrifter::Ping

      def ping
        raise StandardError
      end
    end

    client = down_class.new

    refute client.up?
  end

  def test_returns_true_if_nothing_goes_wrong
    down_class = Class.new do
      include Thrifter::Ping

      def ping
        true
      end
    end

    client = down_class.new

    assert client.up?
  end
end
