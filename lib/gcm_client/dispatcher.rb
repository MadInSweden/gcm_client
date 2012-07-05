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
      STDERR.puts "DISPATCH STARTING.."
      STDERR.puts "SENDING FROM:"
      STDERR.puts self.inspect
      STDERR.puts "REG_IDS:"
      STDERR.puts registration_ids.inspect
      STDERR.puts "PAYLOAD:"
      STDERR.puts payload.inspect
      resp = @http.post 'https://android.googleapis.com/gcm/send', json, headers
      STDERR.puts "SENT.. RESPONSE IS:"
      STDERR.puts resp.inspect
      STDERR.puts "DISPATCH DONE!"

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
