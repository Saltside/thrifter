module Thrifter
  module Ping
    def up?
      ping
      true
    rescue
      false
    end
  end
end
