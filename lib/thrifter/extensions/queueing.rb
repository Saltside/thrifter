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
      def perform(klass, method_name, *args)
        puts "ARGS to perform ----------- #{klass} - #{method_name} - #{args}"
        client = klass.constantize.new
        client.send method_name, *args
      end
    end

    class Proxy
      def initialize(target, queue)
        @target = target
        @queue = queue
      end

      def method_missing(name, *args, &block)
        if target.respond_to? name
          job_args = [ target.class.to_s, name ].concat(args)
          # Job.perform_async(*job_args)
          Sidekiq::Client.push(
            'class' => Job,
            'queue' => queue,
            'args' => job_args
          )
          puts "PUSHED ----------"
        else
          puts "CALLED ---------- #{name}"
          super
        end
      end

      private

      def target
        @target
      end

      def queue
        @queue
      end
    end

    def queued(name = 'default')
      proxy = Proxy.new self, name
      yield proxy if block_given?
      proxy
    end
  end
end
