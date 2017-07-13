module Thrifter
  class InstrumentedPool < ConnectionPool
    attr_reader :statsd

    def initialize(options = { }, &block)
      super(options, &block)
      @statsd = options.fetch(:statsd)
    end

    def checkout(*args)
      statsd.gauge('thread_pool.size', @size)
      statsd.time('thread_pool.latency') do
        super.tap do |conn|
          statsd.increment('thread_pool.checkout')
          statsd.gauge('thread_pool.in_use', in_use)
        end
      end
    rescue Timeout::Error => ex
      statsd.increment('thread_pool.timeout')
      raise ex
    end

    def checkin(*args)
      super.tap do
        statsd.increment('thread_pool.checkin')
        statsd.gauge('thread_pool.in_use', in_use)
      end
    end

    private

    def in_use
      (1 - (@available.length / @size.to_f)).round(2)
    end
  end
end
