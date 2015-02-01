module Thrifter
  RetryError = Tnt.boom do |count, rpc|
    "#{rpc} RPC unsuccessful after #{count} times"
  end

  module Retry
    RETRIABLE_ERRORS = [
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

    class Proxy
      attr_reader :tries, :interval, :client

      def initialize(client, tries, interval, rpcs)
        @client, @tries, @interval = client, tries, interval

        rpcs.each do |name|
          define_singleton_method name do |*args|
            invoke_with_retry(name, *args)
          end
        end
      end

      private

      def invoke_with_retry(name, *args)
        counter = 0

        begin
          counter = counter + 1
          client.send name, *args
        rescue *RETRIABLE_ERRORS => ex
          if counter < tries
            sleep interval
            retry
          else
            raise RetryError.new(tries, name)
          end
        end
      end
    end

    def with_retry(tries: 5, interval: 0.01)
      Proxy.new(self, tries, interval, rpcs).tap do |proxy|
        yield proxy if block_given?
      end
    end
  end
end
