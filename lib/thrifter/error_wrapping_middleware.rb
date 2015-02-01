module Thrifter
  ClientError = Tnt.boom do |ex|
    "#{ex.class}: #{ex.message}"
  end

  class ErrorWrappingMiddleware
    WRAP = [
      Thrift::TransportException,
      Thrift::ProtocolException,
      Thrift::ApplicationException,
      Timeout::Error,

      # This exception is a superclass for all Errno things coming
      # from the operating system network stack. See the documentation
      # on Error no for more information.
      SystemCallError
    ]

    class << self
      def wrapped
        WRAP
      end
    end

    def initialize(app, extras = [ ])
      @app, @extras = app, extras
    end

    def call(rpc)
      app.call rpc
    rescue *wrapped => ex
      raise ClientError, ex
    end

    private

    def app
      @app
    end

    def extras
      @extras
    end

    def wrapped
      self.class.wrapped + extras
    end
  end
end
