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

  class TimeoutPool < Thrifter::InstrumentedPool
    class FakeStack
      def pop(*args)
        raise Timeout::Error
      end
    end

    def initialize(*args, &block)
      super(*args) { :placeholder }
      @available = FakeStack.new
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
    assert latency
    assert_equal 'thread_pool.latency', latency

    counter = statsd.counters[0]
    assert counter
    assert_equal 'thread_pool.checkout', counter[0]
    assert_equal 1, counter[1]

    size = statsd.gauges[0]
    assert size
    assert_equal 'thread_pool.size', size[0]
    assert_equal 5, size[1]

    in_use = statsd.gauges[1]
    assert in_use
    assert_equal 'thread_pool.in_use', in_use[0]
    assert_equal 0.2, in_use[1]
  end

  def test_checkin_instrumentation
    assert pool.checkout
    statsd.clear

    pool.checkin

    counter = statsd.counters[0]
    assert counter
    assert_equal 'thread_pool.checkin', counter[0]
    assert_equal 1, counter[1]

    in_use = statsd.gauges.first
    assert in_use
    assert_equal 'thread_pool.in_use', in_use[0]
    assert_equal 0.0, in_use[1]
  end

  def test_checkout_timeout_instrumentation
    @pool = TimeoutPool.new({
      statsd: statsd,
      size: 5,
      timeout: 5
    })

    assert_raises Timeout::Error do
      pool.checkout
    end

    latency = statsd.timers.first
    assert latency
    assert_equal 'thread_pool.latency', latency

    counter = statsd.counters.first
    assert counter
    assert_equal 'thread_pool.timeout', counter[0]
    assert_equal 1, counter[1]
  end
end
