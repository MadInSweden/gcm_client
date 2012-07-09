module GcmClient

  class Error < RuntimeError; end

  class HTTPError < Error

    # Public API

    attr_reader :response

    def initialize(response)
      @response = response

      super(self.message)
    end

    def message
      "Got HTTP status #{self.response.status} from GCM."
    end

  end

  class TooManyTempFailures < Error
  end

  class GcmError < Error

    # Public API

    attr_reader :result

    def initialize(result)
      @result = result

      super(self.message)
    end

    def message
      "Got result #{self.result['error']} from GCM."
    end

  end

  class PayloadTooLarge < Error

    # Public API

    attr_reader :data
    attr_reader :bytesize

    def initialize(data, bytesize)
      @data, @bytesize = data, bytesize

      super(self.message)
    end

    def message
      "Payload generates a JSON string of #{self.bytesize} bytes, max is #{Payload::DATA_MAX_SIZE} bytes."
    end

  end

end
