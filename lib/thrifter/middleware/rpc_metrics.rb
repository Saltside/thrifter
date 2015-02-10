module Thrifter
  class RpcMetrics
    include Concord.new(:app, :statsd)

    def call(rpc)
      statsd.increment "rpc.#{rpc.name}.outgoing"

      response = statsd.time "rpc.#{rpc.name}.latency" do
        app.call rpc
      end

      statsd.increment "rpc.#{rpc.name}.success"

      response
    rescue Thrift::TransportException => ex
      statsd.increment "rpc.#{rpc.name}.error"
      statsd.increment "rpc.#{rpc.name}.error.transport"
      raise ex
    rescue Thrift::ProtocolException => ex
      statsd.increment "rpc.#{rpc.name}.error"
      statsd.increment "rpc.#{rpc.name}.error.protocol"
      raise ex
    rescue Thrift::ApplicationException => ex
      statsd.increment "rpc.#{rpc.name}.error"
      statsd.increment "rpc.#{rpc.name}.error.application"
      raise ex
    rescue Timeout::Error => ex
      statsd.increment "rpc.#{rpc.name}.error"
      statsd.increment "rpc.#{rpc.name}.error.timeout"
      raise ex
    rescue => ex
      statsd.increment "rpc.#{rpc.name}.error"
      statsd.increment "rpc.#{rpc.name}.error.other"
      raise ex
    end
  end
end
