module GcmClient
  class Response; end

  class SuccessResponse < Response

    # Internal API

    attr_reader :httpresponse, :results

    def initialize(httpresponse, results)
      @httpresponse = httpresponse
      @results      = results
    end

  end

  class ErrorResponse < Response

    # Internal API

    attr_reader :error

    def initialize(error)
      @error = error
    end

  end

  class TempErrorResponse < ErrorResponse; end

  class PermErrorResponse < ErrorResponse; end

end
