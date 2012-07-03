require 'httpclient'

module GcmClient
  class Dispatcher

    attr_reader :api_key, :callbacks, :http

    def initialize(api_key, callbacks={})
      @api_key   = api_key
      @callbacks = callbacks
      @http = HTTPClient.new
    end

    def dispatch(registration_ids, payload)
      json = payload.json_for_registration_ids(registration_ids)
      resp = @http.post 'https://android.googleapis.com/gcm/send', json, headers

      callback(:sent, registration_ids)
    end

    private
      def headers
        { "Content-Type" => "application/json", "Authorization" => "key=#{@api_key}" }
      end

      def callback(name, *args)
        cbk = :"on_#{name}"
        callbacks[cbk].call(*args) if callbacks[cbk]
      end

  end
end
