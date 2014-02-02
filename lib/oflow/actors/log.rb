
require 'logger'

module OFlow
  module Actors

    # An asynchronous logger build on top of the Actor class. It is able to log
    # messages as well as forward calls to a Task.
    class Log < Actor

      SEVERITY_MAP = {
        :fatal => Logger::Severity::FATAL,
        :error => Logger::Severity::ERROR,
        :warn => Logger::Severity::WARN,
        :info => Logger::Severity::INFO,
        :debug => Logger::Severity::DEBUG,
      }
      def initialize(task, options={})
        @logger = nil
        @formatter = nil
        @name = nil
        super
        set_options(options)
      end

      # Returns the current severity level.
      # @return [Fixnum] Logger severity level
      def severity()
        @logger.level
      end
      alias :level :severity

      # Returns the current formatter.
      # @return [Logger::Formatter] current formatter
      def formatter()
        @formatter
      end

      # Writes a log entry. op is the severity. The box contents is expected to be
      # an Array with the first element as the full task name of the logging task
      # and the second argument being the message to log
      def perform(task, op, box)
        a = box.contents
        level = SEVERITY_MAP[op]
        if a.is_a?(Array)
          log(level, a[0], a[1])
        else
          log(level, a.to_s, '')
        end
        # Forward to the next if there is a generic (nil) link.
        task.ship(nil, box) if task.find_link(nil)
      end

      private

      # Sets the logger, severity, and formatter if provided.
      # @param [Hash] options options to be used for initialization
      # @option options [String] :filename filename to write to
      # @option options [Fixnum] :max_file_size maximum file size
      # @option options [Fixnum] :max_file_count maximum number of log file
      # @option options [IO] :stream IO stream
      # @option options [String|Fixnum] :severity initial setting for severity
      # @option options [Proc] :formatter initial setting for the formatter procedure
      def set_options(options)
        if !(filename = options[:filename]).nil?
          max_file_size = options.fetch(:max_file_size, options.fetch(:shift_size, 1048576))
          max_file_count = options.fetch(:max_file_count, options.fetch(:shift_age, 7))
          @logger = Logger.new(filename, max_file_count, max_file_size)
        elsif !(stream = options[:stream]).nil?
          @logger = Logger.new(stream)
        else
          @logger = Logger.new(STDOUT)
        end
        @logger.level = options[:severity] if options.has_key?(:severity)
        @formatter = options.fetch(:formatter, nil)
        @logger.formatter = proc { |s,t,p,m| m }
        @name = 'Logger' if @name.nil?
      end

      # Writes a message if the severity is high enough. This method is
      # executed asynchronously.
      # @param [Fixnum] level one of the Logger levels
      # @param [String] message string to log
      # @param [Fixnum|String] tid Task id of the Task generating the message
      def log(level, message, tid)
        now = Time.now
        ss = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'][level]
        ss = '' if ss.nil?
        if @formatter.nil?
          msg = "#{ss[0]}, [#{now.strftime('%Y-%m-%dT%H:%M:%S.%6N')} #{tid}] #{ss} -- #{message}\n"
        else
          msg = @formatter.call(ss, now, tid, message)
        end
        @logger.add(level, msg)
      end

      # Sets the logger to use the stream specified. This method is executed
      # asynchronously.
      # @param [IO] stream stream to write log messages to
      def stream=(stream)
        logger = Logger.new(stream)
        logger.level = @logger.level
        logger.formatter = @logger.formatter
        @logger = logger
      end

      # Creates a new Logger to write log messages to using the parameters
      # specified. This method is executed asynchronously.
      # @param [String] filename filename of active log file
      # @param [Fixmun] shift_age maximum number of archive files to save
      # @param [Fixmun] shift_size maximum file size
      def set_filename(filename, shift_age=7, shift_size=1048576)
        logger = Logger.new(filename, shift_age, shift_size)
        logger.level = @logger.level
        logger.formatter = @logger.formatter
        @logger = logger
      end

      # Replace the logger with a new Logger Object. This method is executed
      # asynchronously.
      # @param [Logger] logger replacement logger
      def logger=(logger)
        @logger = logger
      end

      # Sets the severity level of the logger. This method is executed
      # asynchronously.
      # @param [String|Fixnum] level value to set the severity to
      def severity=(level)
        if level.is_a?(String)
          severity = {
            'FATAL' => Logger::Severity::FATAL,
            'ERROR' => Logger::Severity::ERROR,
            'WARN' => Logger::Severity::WARN,
            'INFO' => Logger::Severity::INFO,
            'DEBUG' => Logger::Severity::DEBUG,
            '4' => Logger::Severity::FATAL,
            '3' => Logger::Severity::ERROR,
            '2' => Logger::Severity::WARN,
            '1' => Logger::Severity::INFO,
            '0' => Logger::Severity::DEBUG
          }[level.upcase()]
          raise "#{level} is not a severity" if severity.nil?
          level = severity
        elsif level < Logger::Severity::DEBUG || Logger::Severity::FATAL < level
          raise "#{level} is not a severity"
        end
        @logger.level = level
      end

      # Sets the formatter procedure of the logger. This method is executed
      # asynchronously.
      # @param [Proc] proc value to set the formatter to
      def formatter=(proc)
        @formatter = proc
      end

    end # Log
  end # Actors
end # OFlow
