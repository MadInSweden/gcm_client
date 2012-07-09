module GcmClient
  class ResultParser

    # Internal API

    attr_reader :results

    def initialize(reg_ids, data)
      # We want to do all this in init to keep it warped in the connection
      # rescue statement..
      json_data = Yajl.load(data)
      @results  = reg_ids.zip(json_data['results'])
    end

    def each(&blk)
      enum = Enumerator.new { |y|
        self.results.each { |reg_id, result| parse(y, reg_id, result) }
      }
      enum.each(&blk)
    end

    private
      def parse(y, reg_id, result)
        # If reg_id is sent and has a canonical_id, store it
        if result['message_id'] && (canonical_id = result['registration_id'])
          y << [reg_id, :canonical_id, canonical_id]
        end

        # If reg_id is sent, store and return
        if result['message_id']
          y << [reg_id, :sent]
          return
        end

        # If reg_id is temp failed, store and return
        if result['error'] == 'Unavailable'
          y << [reg_id, :temp_fail, GcmError.new(result)]
          return
        end

        # If reg_id is perm failed because it's NotRegistered, store
        if result['error'] == 'NotRegistered'
          y << [reg_id, :not_registered]
        end

        # If reg_id is perm failed, store and return
        if result['error']
          y << [reg_id, :perm_fail, GcmError.new(result)]
          return
        end
      end

  end
end
