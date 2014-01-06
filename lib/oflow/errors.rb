
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

end # OFlow
