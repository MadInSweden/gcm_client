module GcmClient
  class Dispatcher

    # Internal API

    attr_reader :api_key, :connection, :callbacks

    # Public API

    # Init a dispatcher object
    #
    # @param api_key String
    #
    # @param callbacks Hash (Symbol => Proc)
    #   :on_not_registered => Proc
    #     @param dispatcher Dispatcher
    #     @param registration_id Fixnum
    #   :on_canonical_id => Proc
    #     @param dispatcher Dispatcher
    #     @param registration_id Fixnum
    #     @param new_registration_id Fixnum
    #   :on_temp_fail => Proc
    #     @param dispatcher Dispatcher
    #     @param registration_id Fixnum
    #     @param error Exception
    #   :on_perm_fail => Proc
    #     @param dispatcher Dispatcher
    #     @param registration_id Fixnum
    #     @param error Exception
    #   :on_send => Proc
    #     @param dispatcher Dispatcher
    #     @param registration_id Fixnum
    #
    # Callbacks :on_msg_send and :on_msg_perm_fail is mutually
    # exclusive, only one of them will be sent.
    #
    # Callback :on_not_registered indicates a NotRegistered error from
    # GCM concerning the registration_id. The registration_id should be
    # removed from send lists.
    #
    # Callback :on_canonical_id indicates a canonical_id mesasge from
    # GCM, old registration_id should be replaced by the new one.
    #
    def initialize(api_key, callbacks={})
      @api_key   = api_key
      @callbacks = callbacks
      @connection = Connection.new(api_key)
    end

    def dispatch(registration_ids, payload)
      d = Dispatch.new(self, registration_ids, payload)
      d.dispatch!
    end

  end
end
