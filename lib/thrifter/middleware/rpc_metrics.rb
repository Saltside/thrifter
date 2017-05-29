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
      case ex.type
      when Thrift::TransportException::UNKNOWN
        statsd.increment "rpc.#{rpc.name}.error.transport.unknown"
      when Thrift::TransportException::NOT_OPEN
        statsd.increment "rpc.#{rpc.name}.error.transport.not_open"
      when Thrift::TransportException::ALREADY_OPEN
        statsd.increment "rpc.#{rpc.name}.error.transport.already_open"
      when Thrift::TransportException::TIMED_OUT
        statsd.increment "rpc.#{rpc.name}.error.transport.timeout"
      when Thrift::TransportException::END_OF_FILE
        statsd.increment "rpc.#{rpc.name}.error.transport.eof"
      end
      raise ex
    rescue Thrift::ProtocolException => ex
      statsd.increment "rpc.#{rpc.name}.error"
      case ex.type
      when Thrift::ProtocolException::UNKNOWN
        statsd.increment "rpc.#{rpc.name}.error.protocol.unknown"
      when Thrift::ProtocolException::INVALID_DATA
        statsd.increment "rpc.#{rpc.name}.error.protocol.invalid_data"
      when Thrift::ProtocolException::NEGATIVE_SIZE
        statsd.increment "rpc.#{rpc.name}.error.protocol.negative_size"
      when Thrift::ProtocolException::SIZE_LIMIT
        statsd.increment "rpc.#{rpc.name}.error.protocol.size_limit"
      when Thrift::ProtocolException::BAD_VERSION
        statsd.increment "rpc.#{rpc.name}.error.protocol.bad_version"
      when Thrift::ProtocolException::NOT_IMPLEMENTED
        statsd.increment "rpc.#{rpc.name}.error.protocol.not_implemented"
      when Thrift::ProtocolException::DEPTH_LIMIT
        statsd.increment "rpc.#{rpc.name}.error.protocol.depth_limit"
      end
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
