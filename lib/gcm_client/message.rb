module GcmClient
  class Message

    attr_reader :registration_id, :payload

    def initialize(registration_id, payload)
      @registration_id, @payload = registration_id, payload
    end

  end
end
