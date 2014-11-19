
module OFlow

  # Adds the ability to log by sending log requests to a log Task.
  module HasLog

    # Sets the log attribute.
    # @param t [Task] log Task
    def log=(t)
      @log = t
    end
    
    # Lower level logging method. Generally only used when one of the primary
    # severity methods are called.
    # @param level [String] message severity or level
    # @param msg [String] message to log
    # @param fn [String] full name of Task or Flow calling the log function
    def log_msg(level, msg, fn)
      # Abort early if the log severity/level would not log the message. This
      # also allows non-Loggers to be used in place of the Log Actor.
      return if Env.log_level > Actors::Log::SEVERITY_MAP[level]

      lt = log()
      # To prevent infinite looping, don't allow the logger to log to itself.
      return if self == lt

      unless lt.nil?
        lt.receive(level, Box.new([msg, fn]))
      else
        puts "[#{fn}] #{msg}"
      end
    end

    # Logs the message if logging level is at least debug.
    # @param msg [String] message to log
    def debug(msg)
      log_msg(:debug, msg, full_name())
    end

    # Logs the message if logging level is at least info.
    # @param msg [String] message to display or log
    def info(msg)
      log_msg(:info, msg, full_name())
    end

    # Logs the message if logging level is at least error.
    # @param msg [String] message to display or log
    def error(msg)
      log_msg(:error, msg, full_name())
    end

    # Logs the message if logging level is at least warn.
    # @param msg [String] message to display or log
    def warn(msg)
      log_msg(:warn, msg, full_name())
    end

    # Logs the message if logging level is at least fatal.
    # @param msg [String] message to display or log
    def fatal(msg)
      log_msg(:fatal, msg, full_name())
    end

  end # HasLog
end # OFlow
