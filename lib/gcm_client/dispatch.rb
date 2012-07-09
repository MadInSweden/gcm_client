module GcmClient

  class Dispatch

    # Specified as max value in GCM specification
    MAX_BATCH_SIZE = 1000

    # These GCM errors could be solvable with a retry
    GCM_TEMP_ERRORS = ['Unavailable']

    # This seems resonable.
    MAX_RETRIES = 5

    # Internal API

    attr_reader :dispatcher, :connection, :callbacks, :send_que, :payload, :failures

    def initialize(dispatcher, registration_ids, payload)
      @dispatcher = dispatcher
      @connection = dispatcher.connection
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
        response = self.connection.post(payload, reg_ids)

        case response
        when SuccessResponse
          response.results.each { |reg_id, result| parse_gcm_result(reg_id, result) }
        when TempErrorResponse
          reg_ids.each { |reg_id| temp_fail(reg_id, response.error) }
        when PermErrorResponse
          reg_ids.each { |reg_id| perm_fail(reg_id, response.error) }
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

      ## reg_id livecycle handlers

      def sent(reg_id)
        callback(:sent, reg_id)
      end

      def not_registered(reg_id)
        callback(:not_registered, reg_id)
      end

      def canonical_id(reg_id, canonical_id)
        callback(:canonical_id, reg_id, canonical_id)
      end

      def temp_fail(reg_id, e)
        callback(:temp_fail, reg_id, e)

        if too_many_temp_failures?(reg_id)
          perm_fail(reg_id, TooManyTempFailures.new)
        else
          self.send_que.push(reg_id)
        end
      end

      def perm_fail(reg_id, e)
        callback(:perm_fail, reg_id, e)
      end

      ## reg_id livecycle helpers

      def too_many_temp_failures?(reg_id)
        self.failures[reg_id] ||= 0
        self.failures[reg_id] += 1
        self.failures[reg_id] >= MAX_RETRIES
      end

      ## Callback helper

      def callback(name, reg_id, *args)
        cbk = self.callbacks[:"on_#{name}"]
        cbk.call(self.dispatcher, reg_id, *args) if cbk
      end

  end
end
