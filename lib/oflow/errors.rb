
module OFlow
  # An Exception indicating a Task was currently not receiving new requests.
  class BlockedError < Exception
    def initialize(option, msg)
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

  # An Exception indicating an error in setup or configuration.
  class ConfigError < Exception
    def initialize(msg)
      super(msg)
    end
  end # ConfigError

  # An Exception raised when no destination is found.
  class LinkError < Exception
    def initialize(dest)
      super("No destination found for '#{dest}'.")
    end
  end # LinkError

end # OFlow
