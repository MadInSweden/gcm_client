module C2dmClient
  class Dispatcher

    attr_reader :username, :password

    def initialize(username, password)
      @username, @password = username, password
    end

  end
end
