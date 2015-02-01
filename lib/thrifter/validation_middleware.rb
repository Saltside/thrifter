module Thrifter
  ValidationError = Tnt.boom do |rpc, ex|
    "Invalid data in RPC #{rpc.name}! #{ex.message}"
  end
  class ValidationMiddleware
    include Concord.new(:app)

    def call(rpc)
      validate rpc, rpc.args
      response = app.call rpc

      validate rpc, Array(response)

      response
    end

    private

    def validate(rpc, objects)
      objects.each do |item|
        if item.is_a? Thrift::Struct
          begin
            Thrift::Validator.new.validate(item)
          rescue Thrift::ProtocolException => ex
            raise ValidationError.new(rpc, ex)
          end
        else
          next
        end
      end
    end
  end
end
