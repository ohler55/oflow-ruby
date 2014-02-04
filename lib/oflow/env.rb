
module OFlow

  # The platform that Flows are created in. It is the outer most element of the
  # OFlow system.
  class Env

    extend HasTasks
    extend HasLog
    extend HasName
    extend HasErrorHandler

    # The default logging level.
    @@log_level = Logger::WARN

    init_name(nil, '')
    init_tasks()

    # Returns the default log level.
    # @return [Fixnum] the default log level which is one of the Logger::Severity values.
    def self.log_level()
      @@log_level
    end

    # Sets the default log level.
    # @param level [Fixnum] Logger::Severity to set the default log level to
    def self.log_level=(level)
      @@log_level = level unless level < Logger::Severity::DEBUG || Logger::Severity::FATAL < level
    end

    # Resets the error handler and log. Usually called on init and by the
    # clear() method.
    def self._clear()
      @error_handler = Task.new(self, :error, Actors::ErrorHandler)
      @log = Task.new(self, :log, Actors::Log)
    end

    _clear()

    # Describes all the Flows and Tasks in the system.
    def self.describe(detail=0, indent=0)
      i = ' ' * indent
      lines = ["#{i}#{self} {"]
      @tasks.each_value { |t|
        lines << t.describe(detail, indent + 2)
      }
      lines << i + "}"
      lines.join("\n")
    end

  end # Env
end # OFlow
