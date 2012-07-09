require 'httpclient'

module GcmClient
  class Connection

    # GCM Endpoint
    GCM_URL = 'https://android.googleapis.com/gcm/send'

    # We only accept HTTP STATUS 200 as an indication of successfull POST
    SUCCESS_CODE = 200

    # Status codes 500 and 503 indicates problems that _could_ be resolved
    # by a resend.
    TEMP_ERROR_CODES = [500, 503]

    # These exceptions _could_ be solved by a resend.
    TEMP_ERRORS = [
      HTTPClient::BadResponseError,
      HTTPClient::TimeoutError,
      OpenSSL::SSL::SSLError,
      Errno::EADDRNOTAVAIL,
      Errno::ETIMEDOUT,
    ]

    # Internal API

    attr_reader :headers, :httpclient

    def initialize(api_key)
      @headers = { "Content-Type" => "application/json", "Authorization" => "key=#{api_key}" }
      @httpclient = HTTPClient.new
      @httpclient.receive_timeout    = 30
      @httpclient.connect_timeout    = 30
      @httpclient.send_timeout       = 30
      @httpclient.keep_alive_timeout = 15
    end

    def post(payload, reg_ids)
      json_data = payload.json_for_registration_ids(reg_ids)
      response = self.httpclient.post(GCM_URL, json_data, self.headers)

      if response.status == SUCCESS_CODE
        data    = Yajl.load(response.body)
        results = reg_ids.zip(data['results'])
        SuccessResponse.new(response, results)
      else
        raise HTTPError.new(response)
      end

    rescue => e
      if temp_error?(e)
        TempErrorResponse.new(e)
      else
        PermErrorResponse.new(e)
      end
    end

    private
      def temp_error?(e)
        TEMP_ERRORS.include?(e.class) || (e.is_a?(HTTPError) && TEMP_ERROR_CODES.include?(e.response.status))
      end

  end
end
