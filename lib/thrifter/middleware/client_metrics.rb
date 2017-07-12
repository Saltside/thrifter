module Thrifter
  class ClientMetrics
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.increment 'rpc.outgoing'

      response = statsd.time "rpc.latency" do #{rpc.name do
        app.call rpc
      end

      statsd.increment 'rpc.success'

      response
    rescue Thrift::TransportException => ex
      statsd.increment 'rpc.error'
      statsd.increment 'rpc.error.transport'
      raise ex
    rescue Thrift::ProtocolException => ex
      statsd.increment 'rpc.error'
      statsd.increment 'rpc.error.protocol'
      raise ex
    rescue Thrift::ApplicationException => ex
      statsd.increment 'rpc.error'
      statsd.increment 'rpc.error.application'
      raise ex
    rescue Timeout::Error => ex
      statsd.increment 'rpc.error'
      statsd.increment 'rpc.error.timeout'
      raise ex
    rescue Thrifter::RetryError  => ex
      statsd.increment 'rpc.error'
      statsd.increment 'rpc.error.retry'
      raise ex
    rescue => ex
      statsd.increment 'rpc.error'
      statsd.increment 'rpc.error.other'
      raise ex
    end
  end
end
