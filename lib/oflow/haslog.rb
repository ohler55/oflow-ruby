
module OFlow

  module HasLog
    attr_accessor :log

    # Logs the message if logging level is at least debug.
    # @param msg [String] message to log
    def debug(msg)
      raise ConfigError.new('logger not set up') if @log.nil?
      @log.receive(:debug, Box.new([msg, self.name]))
    end

    # Logs the message if logging level is at least info.
    # @param msg [String] message to display or log
    def info(msg)
      raise ConfigError.new('logger not set up') if @log.nil?
      @log.receive(:info, Box.new([msg, self.name]))
    end

    # Logs the message if logging level is at least error.
    # @param msg [String] message to display or log
    def error(msg)
      raise ConfigError.new('logger not set up') if @log.nil?
      @log.receive(:error, Box.new([msg, self.name]))
    end

    # Logs the message if logging level is at least warn.
    # @param msg [String] message to display or log
    def warn(msg)
      raise ConfigError.new('logger not set up') if @log.nil?
      @log.receive(:warn, Box.new([msg, self.name]))
    end

    # Logs the message if logging level is at least fatal.
    # @param msg [String] message to display or log
    def fatal(msg)
      raise ConfigError.new('logger not set up') if @log.nil?
      @log.receive(:fatal, Box.new([msg, self.name]))
    end

  end # HasLog
end # OFlow
