require 'yajl'

module GcmClient
  PAYLOAD_DATA_MAX_SIZE = 2048

  class PayloadTooLarge < RuntimeError

    # Public API

    attr_reader :data
    attr_reader :bytesize

    def initialize(data, bytesize)
      @data, @bytesize = data, bytesize

      super(self.message)
    end

    def message
      "Payload generates a JSON string of #{self.bytesize} bytes, max is #{PAYLOAD_DATA_MAX_SIZE} bytes."
    end

  end

  # Payload encapsulates and serializes all info in common between
  # multiple receivers of the same apns message.
  class Payload

    # Public API

    def initialize(data)
      data_hash = data.each_with_object({}) { |(k,v), h| h[k.to_s] = v.to_s }
      data_json = Yajl.dump(data_hash)

      @json_fmt = %Q[{"registration_ids":%s,"data":#{data_json}}]
      @data_bytesize = data_json.bytesize

      check_size!(data)
    end

    # Returns bytesize of data part of JSON payload
    def bytesize
      @data_bytesize
    end

    # Constructs JSON payload
    def json_for_registration_ids(registration_ids)
      @json_fmt % Yajl.dump(registration_ids.map(&:to_s))
    end

    # Internal API

    private
      def check_size!(data)
        raise PayloadTooLarge.new(data, bytesize) if self.bytesize > PAYLOAD_DATA_MAX_SIZE
      end
  end
end
