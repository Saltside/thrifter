module Thrifter
  class StatsdMiddleware
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.time rpc.name do
        app.call rpc
      end
    rescue Thrift::TransportException => ex
      statsd.increment 'errors.transport'
      raise ex
    rescue Thrift::ProtocolException => ex
      statsd.increment 'errors.protocol'
      raise ex
    rescue Thrift::ApplicationException => ex
      statsd.increment 'errors.application'
      raise ex
    rescue Timeout::Error => ex
      statsd.increment 'errors.timeout'
      raise ex
    rescue => ex
      statsd.increment 'errors.other'
      raise ex
    end
  end
end
