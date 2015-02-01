require 'sidekiq'
require 'sidekiq-thrift_arguments'

module Thrifter
  module Queueing
    class Job
      include Sidekiq::Worker
      include Sidekiq::ThriftArguments

      # NOTE: sidekiq-thrift_arguments does not recurse into
      # arguments. The thrift objects must not be inside an array or
      # other structure. This is why the method has so many arguments.
      # Sidekik-thrift_arguments will correctly pick up any complex
      # type in the splat and handle serialization/deserialization
      def perform(klass, rpc_name, *rpc_args)
        client = klass.constantize.new
        client.send rpc_name, *rpc_args
      end
    end

    class Proxy
      def initialize(klass, rpcs)
        rpcs.each do |name|
          define_singleton_method name do |*args|
            job_args = [ klass.to_s, name ].concat(args)
            Job.perform_async(*job_args)
          end
        end
      end
    end

    def queued
      Proxy.new(self.class, rpcs).tap do |proxy|
        yield proxy if block_given?
      end
    end
  end
end
