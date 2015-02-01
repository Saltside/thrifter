require 'thrifter/version'

require 'forwardable'
require 'delegate'
require 'uri'
require 'tnt'
require 'concord'
require 'thrift'
require 'thrift-base64'
require 'thrift-validator'
require 'middleware'
require 'connection_pool'

module Thrifter
  RPC = Struct.new(:name, :args)

  class MiddlewareStack < Middleware::Builder
    def finalize!
      stack.freeze
      to_app
    end
  end

  class NullStatsd
    def time(*)
      yield
    end

    def increment(*)

    end
  end

  RESERVED_METHODS = [
    :send_message,
    :send_oneway_message,
    :send_message_args
  ]

  Configuration = Struct.new :transport, :protocol,
    :pool_size, :pool_timeout,
    :uri, :rpc_timeout,
    :stack, :statsd

  class << self
    def build(client_class, &block)
      rpcs = client_class.instance_methods.each_with_object([ ]) do |method_name, rpcs|
        next if RESERVED_METHODS.include? method_name
        next unless method_name =~ /^send_(?<rpc>.+)$/
        rpcs << Regexp.last_match[:rpc].to_sym
      end

      rpcs.freeze

      Class.new Client do
        rpcs.each do |rpc_name|
          define_method rpc_name do |*args|
            invoke RPC.new(rpc_name, args)
          end
        end

        class_eval(&block) if block

        private

        define_method :rpcs do
          rpcs
        end

        define_method :client_class do
          client_class
        end
      end
    end
  end

  class Client
    class Dispatcher
      include Concord.new(:app, :transport, :client)

      def call(rpc)
        transport.open
        client.send rpc.name, *rpc.args
      ensure
        transport.close
      end
    end

    class DirectDispatcher
      include Concord.new(:app, :client)

      def call(rpc)
        client.send rpc.name, *rpc.args
      end
    end

    class << self
      extend Forwardable

      attr_accessor :config

      def_delegators :config, :stack
      def_delegators :stack, :use

      def configure
        yield config
      end

      # NOTE: the inherited hook is better than doing singleton
      # methods for config. This works when Thrifter is used like a
      # struct MyClient = Thrifter.build(MyService) or like delegate
      # class MyClient < Thrifter.build(MyService). The end result is
      # each class has it's own configuration instance.
      def inherited(base)
        base.config = Configuration.new
        base.configure do |config|
          config.transport = Thrift::FramedTransport
          config.protocol = Thrift::BinaryProtocol
          config.pool_size = 12
          config.pool_timeout = 0.1
          config.rpc_timeout = 0.3
          config.statsd = NullStatsd.new
          config.stack = MiddlewareStack.new
        end
      end
    end

    def initialize(client = nil)
      if client.nil?
        fail ArgumentError, 'config.uri not set!' unless config.uri

        uri = URI(config.uri)

        fail ArgumentError, 'URI did not contain port' unless uri.port
      end

      @pool = ConnectionPool.new size: config.pool_size.to_i, timeout: config.pool_timeout.to_f do
        stack = MiddlewareStack.new

        stack.use config.stack

        # Insert metrics here so metrics are as close to the network
        # as possible. This excludes time in any middleware an
        # application may have configured.
        stack.use Metrics, config.statsd

        if client.nil?
          socket = Thrift::Socket.new uri.host, uri.port, config.rpc_timeout.to_f
          transport = config.transport.new socket
          protocol = config.protocol.new transport

          stack.use Dispatcher, transport, client_class.new(protocol)
        else
          stack.use DirectDispatcher, client
        end

        stack.finalize!
      end
    end

    private

    def pool
      @pool
    end

    def config
      self.class.config
    end

    def invoke(rpc)
      pool.with do |stack|
        stack.call rpc
      end
    end
  end
end

require_relative 'thrifter/extensions/ping'
require_relative 'thrifter/extensions/retriable'

require_relative 'thrifter/middleware/error_wrapping'
require_relative 'thrifter/middleware/validation'
require_relative 'thrifter/middleware/metrics'
