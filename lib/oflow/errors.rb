
module OFlow
  # An Exception indicating a Task was currently not receiving new requests.
  class BlockedError < Exception
    def initialize()
      super("Blocked, try again later")
    end
  end # BlockedError

  # An Exception indicating a Task was too busy to complete the requested
  # operation.
  class BusyError < Exception
    def initialize()
      super("Busy, try again later")
    end
  end # BusyError

  # An Exception indicating a data value is frozen and can not be modified.
  class FrozenError < Exception
    def initialize(name, value)
      super("#{name}, a #{value.class} Object is frozen")
    end
  end # FrozenError

  # An Exception indicating an error in setup or configuration.
  class ConfigError < Exception
    def initialize(msg)
      super(msg)
    end
  end # ConfigError

  # An Exception indicating an invalid operation used in a call to receive() or
  # perform().
  class OpError < Exception
    def initialize(name, op)
      super("'#{op}' is not a valid operation for #{name}.")
    end
  end # OpError

  # An Exception raised when no destination is found.
  class LinkError < Exception
    def initialize(dest)
      super("No destination found for '#{dest}'.")
    end
  end # LinkError

  # An Exception raised when there are validation errors.
  class ValidateError < Exception
    attr_accessor :problems

    def initialize(errors)
      @problems = errors
      ma = ["#{errors.size} validation errors."]
      errors.each { |e| ma << e.to_s }
      super(ma.join("\n  "))
    end

    class Problem
      LINK_ERROR = 'link_error'
      MISSING_ERROR = 'missing_link_error'
      INPUT_ERROR = 'input_link_error'

      attr_reader :task_name
      attr_reader :kind
      attr_reader :message

      def initialize(task_name, kind, msg)
        @task_name = task_name
        @kind = kind
        @message = msg
      end
      
      def to_s()
        "#{@task_name}: #{@message}"
      end
      alias inpsect to_s

    end # Problem

  end # ValidateError

end # OFlow
