# Licensed under the Apache 2 License
# (C)2024 Tom Noonan II

class BasicUrl
  module Errors
    class BasicUrlError < StandardError
    end

    class InternalError < StandardError
    end

    #
    # Input Validation Errors
    #
    class ValidationFault < StandardError
    end

    class ComponentTypeError < ValidationFault
    end

    class InvalidComponent < ValidationFault
    end

    class InvalidURL < ValidationFault
    end
  end
end
