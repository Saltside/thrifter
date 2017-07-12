module Thrifter
  RetryError = Tnt.boom do |count, rpc, exception|
    "#{rpc} RPC unsuccessful after #{count} times. #{exception.class}: #{exception.message}"
  end

  module Retry
    DEFAULT_RETRIABLE_ERRORS = [
      ClientError,
      Thrift::TransportException,
      Thrift::ProtocolException,
      Thrift::ApplicationException,
      Timeout::Error,
      Errno::ECONNREFUSED,
      Errno::EADDRNOTAVAIL,
      Errno::EHOSTUNREACH,
      Errno::EHOSTDOWN,
      Errno::ETIMEDOUT
    ]

    class Proxy < BasicObject
      attr_reader :tries, :interval, :client, :retriable

      def initialize(client, tries, interval, retriable)
        @client = client
        @tries = tries
        @interval = interval
        @retriable = DEFAULT_RETRIABLE_ERRORS + Array(retriable)
      end

      private

      def method_missing(name, *args)
        invoke_with_retry(name, *args)
      end

      def invoke_with_retry(name, *args)
        counter = 0

        begin
          counter = counter + 1
          client.send name, *args
        rescue *retriable => ex
          if counter < tries
            config.statsd.increment("rpc.#{name}.retry")
            sleep interval
            retry
          else
            config.statsd.increment("rpc.#{name}.retry")
            raise RetryError.new(tries, name, ex)
          end
        end
      end
    end

    def with_retry(tries: 5, interval: 0.01, retriable: [ ])
      proxy = Proxy.new self, tries, interval, retriable
      yield proxy if block_given?
      proxy
    end
  end
end
