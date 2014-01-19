
module OFlow

  module HasLog

    def log()
      return @log if instance_variable_defined?(:@log) && !@log.nil?
      # Log task take precedence over log variable.
      if respond_to?(:find_task)
        lg = find_task(:log)
        return lg unless lg.nil?
      end
      return @flow.log if instance_variable_defined?(:@flow) && @flow.respond_to?(:log)
      nil
    end

    def log_msg(level, msg)
      lt = log()
      unless lt.nil?
        lt.receive(level, Box.new([msg, full_name()]))
      else
        puts "[#{full_name()}] #{msg}"
      end
    end

    # Logs the message if logging level is at least debug.
    # @param msg [String] message to log
    def debug(msg)
      log_msg(:debug, msg)
    end

    # Logs the message if logging level is at least info.
    # @param msg [String] message to display or log
    def info(msg)
      log_msg(:info, msg)
    end

    # Logs the message if logging level is at least error.
    # @param msg [String] message to display or log
    def error(msg)
      log_msg(:error, msg)
    end

    # Logs the message if logging level is at least warn.
    # @param msg [String] message to display or log
    def warn(msg)
      log_msg(:warn, msg)
    end

    # Logs the message if logging level is at least fatal.
    # @param msg [String] message to display or log
    def fatal(msg)
      log_msg(:fatal, msg)
    end

  end # HasLog
end # OFlow
