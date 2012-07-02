require 'yajl'

module GcmClient
  # Payload encapsulates and serializes all info in common between
  # multiple receivers of the same apns message.
  class Payload

    def initialize(data)
      data_hash = {}
      data.each_pair { |k,v| data_hash[k.to_s] = v.to_s }
      @json_fmt = %Q[{"registration_ids":%s,"data":#{Yajl.dump(data_hash)}}]
    end

    def json_for_registration_ids(registration_ids)
      @json_fmt % Yajl.dump(registration_ids.map(&:to_s))
    end


  end
end
