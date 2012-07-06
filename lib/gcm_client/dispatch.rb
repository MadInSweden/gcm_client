module GcmClient

  class TooManyTempFailures < RuntimeError
  end

  class HTTPError < RuntimeError

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

  class GcmError < RuntimeError

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

  class Dispatch

    # Specified as max value in GCM specification
    MAX_BATCH_SIZE = 1000

    # These GCM errors could be solvable with a retry
    GCM_TEMP_ERRORS = ['Unavailable']

    # This seems resonable.
    MAX_RETRIES = 5

    # Internal API

    attr_reader :dispatcher, :send_que, :payload, :callbacks, :failures

    def initialize(dispatcher, registration_ids, payload)
      @dispatcher = dispatcher
      @callbacks = dispatcher.callbacks
      @send_que = registration_ids.dup
      @payload = payload
      @failures = {}
    end

    def dispatch!
      until (batch = self.send_que.shift(MAX_BATCH_SIZE)).empty?
        dispatch_batch!(batch)
      end
    end

    private

      ## Message dispatch

      def dispatch_batch!(reg_ids)
        response = post(json(reg_ids))
        parse_http_response(reg_ids, response)
      rescue HTTPError => e
        case e.response.status
        when 500,503
          temp_fails(reg_ids, e)
        else
          perm_fails(reg_ids, e)
        end
      rescue HTTPClient::BadResponseError,
             HTTPClient::TimeoutError,
             OpenSSL::SSL::SSLError,
             Errno::ETIMEDOUT,
             Errno::EADDRNOTAVAIL => e
        temp_fails(reg_ids, e)
      rescue => e
        perm_fails(reg_ids, e)
      end

      def parse_http_response(reg_ids, response)
        reg_ids.zip(Yajl.load(response.body)['results']).each do |reg_id, result|
          parse_gcm_result(reg_id, result)
        end
      end

      def parse_gcm_result(reg_id, result)
        if result['message_id']
          canonical_id(reg_id, result['registration_id']) if result['registration_id']
          sent(reg_id)
        elsif GCM_TEMP_ERRORS.include?(result['error'])
          temp_fail(reg_id, GcmError.new(result))
        else
          not_registered(reg_id) if result['error'] == 'NotRegistered'
          perm_fail(reg_id, GcmError.new(result))
        end
      end

      ## Message dispatch helpers

      def json(reg_ids)
        self.payload.json_for_registration_ids(reg_ids)
      end

      ## reg_id livecycle handlers

      def temp_fails(reg_ids, e)
        reg_ids.each { |reg_id| temp_fail(reg_id, e) }
      end

      def perm_fails(reg_ids, e)
        reg_ids.each { |reg_id| perm_fail(reg_id, e) }
      end

      def sent(reg_id)
        callback(reg_id, :sent)
      end

      def not_registered(reg_id)
        callback(reg_id, :not_registered)
      end

      def canonical_id(reg_id, canonical_id)
        callback(reg_id, :canonical_id, canonical_id)
      end

      def temp_fail(reg_id, e)
        callback(reg_id, :temp_fail, e)

        if too_many_temp_failures?(reg_id)
          perm_fail(reg_id, TooManyTempFailures.new)
        else
          self.send_que.push(reg_id)
        end
      end

      def perm_fail(reg_ids, e)
        callback(reg_ids, :perm_fail, e)
      end

      ## Message Status helpers

      def too_many_temp_failures?(reg_id)
        self.failures[reg_id] ||= 0
        self.failures[reg_id] += 1
        self.failures[reg_id] >= MAX_RETRIES
      end

      def post(json)
        self.dispatcher.post(json).tap do |response|
          raise(HTTPError.new(response)) if response.status != 200
        end
      end

      ## Callback helper

      def callback(reg_id, name, *args)
        cbk = self.callbacks[:"on_#{name}"]
        cbk.call(self.dispatcher, reg_id, *args) if cbk
      end

  end
end
