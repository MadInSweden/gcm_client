module C2dmClient
  # Payload encapsulates and serializes all info in common between
  # multiple receivers of the same apns message.
  #
  # The same Payload instance can be used for multiple Message
  # instances, in order to optimize serialization compution time.
  class Payload

    def initialize(collapse_key, data={})
      @hash = { 'collapse_key' => collapse_key.to_s }
      data.each_pair { |k,v| @hash['data.%s' % k] = v.to_s }
      @hash.freeze
    end

    def to_hash
      @hash
    end

  end
end
