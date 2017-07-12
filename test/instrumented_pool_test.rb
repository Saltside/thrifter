require_relative 'test_helper'

class InstrumentedPoolTest < MiniTest::Unit::TestCase
  class TestStatsd
    attr_reader :timers, :gauges, :counters

    def initialize
      @timers = [ ]
      @gauges = [ ]
      @counters = [ ]
    end

    def clear
      timers.clear
      gauges.clear
      counters.clear
    end

    def time(key)
      timers << key
      yield
    end

    def increment(key, value = 1)
      counters << [ key, value ]
    end

    def gauge(key, value)
      gauges << [ key, value ]
    end
  end

  attr_reader :pool, :statsd

  def setup
    super

    @statsd = TestStatsd.new
    @pool = Thrifter::InstrumentedPool.new(size: 5, timeout: 5, statsd: statsd) do
      :foo
    end
  end

  def test_checkout_instrumentation
    assert_equal :foo,  pool.checkout, 'Incorrect connection'

    latency = statsd.timers.first
    assert_equal 'thread_pool.latency', latency

    counter = statsd.counters.first
    assert_equal 'thread_pool.checkout', counter[0]
    assert_equal 1, counter[1]

    in_use = statsd.gauges.first
    assert_equal 'thread_pool.in_use', in_use[0]
    assert_equal 0.2, in_use[1]
  end

  def test_checkin_instrumentation
    assert pool.checkout
    statsd.clear

    pool.checkin

    counter = statsd.counters.first
    assert_equal 'thread_pool.checkin', counter[0]
    assert_equal 1, counter[1]

    in_use = statsd.gauges.first
    assert_equal 'thread_pool.in_use', in_use[0]
    assert_equal 0.0, in_use[1]
  end
end
