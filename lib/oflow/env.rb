
module OFlow

  # The platform that Flows are created in. It is the outer most element of the
  # OFlow system.
  class Env

    extend HasLog
    extend HasErrorHandler

    # The default logging level.
    @@log_level = Logger::WARN

    @@flows = {}

    def self.full_name()
      ''
    end

    # Creates a Flow and yield to a block with the newly create Flow. Used to
    # contruct Flows.
    # @param name [Symbol|String] base name for the Flow
    # @param options [Hash] optional parameters
    # @param block [Proc] block to yield to with the new Flow instance
    # @return [Flow] new Flow
    def self.flow(name, options={}, &block)
      f = Flow.new(self, name, options)
      @@flows[f.name] = f
      yield(f) if block_given?
      f.resolve_all_links()

      # TBD should validate wait until all are completed
      f.validate() 
      f.start()

      f
    end

    # Validates the container by verifying all links on a task have been set to
    # a valid destination and that destination has been resolved.
    # @raise [ValidateError] if there is an error in validation
    def self.validate()
      # collects errors and raises all errors at once if there are any
      errors = _validation_errors()
      raise ValidateError.new(errors) unless errors.empty?
    end

    # Returns an Array of validation errors.
    def self._validation_errors()
      errors = []
      @flows.each_value { |f| errors += f._validation_errors() }
      errors
    end

    # Resolves all the Links on all the Flows being managed.
    def self.resolve_all_links()
      @@flows.each_value { |f|
        f.resolve_all_links()
      }
    end

    # Iterates over each Flow and yields to the provided block with each Flow.
    # @param blk [Proc] Proc to call on each iteration
    def self.each_flow(&blk)
      @@flows.each { |name,flow| blk.yield(flow) }
    end

    # Performs a recursive walk over all Flows and yields to the provided block
    # for each.
    # @param blk [Proc] Proc to call on each iteration
    def self.walk_flows(&blk)
      @@flows.each_value do |f|
        blk.yield(t)
      end
    end

    # Performs a recursive walk over all Tasks in all Flows and yields to the
    # provided block for each.
    # @param blk [Proc] Proc to call on each iteration
    def self.walk_tasks(&blk)
      @@flows.each_value do |f|
        f.walk_tasks(&blk)
      end
    end

    # Locates and return a Flow with the specified name.
    # @param name [String] name of the Flow
    # @return [Flow|nil] the Flow with the name specified or nil
    def self.find_flow(name)
      name = name.to_sym unless name.nil?
      @@flows[name]
    end

    # Locates and return a Task with the specified full name.
    # @param name [String] full name of the Task
    # @return [Flow|Task|nil] the Flow or Task with the name specified or nil
    def self.locate(name)
      name = name[1..-1] if name.start_with?(':')
      name = name[0..-2] if name.end_with?(':')
      path = name.split(':')
      _locate(path)
    end

    def self._locate(path)
      f = @@flows[path[0].to_sym]
      return f if f.nil? || 1 == path.size
      f._locate(path[1..-1])
    end

    # Returns the number of active Tasks.
    def self.flow_count()
      @@flows.size
    end

    # Returns the sum of all the requests in all the Flow's Task's queues.
    # @return [Fixnum] total number of items waiting to be processed
    def self.queue_count()
      cnt = 0
      @@flows.each_value { |f| cnt += f.queue_count() }
      cnt
    end

    # Returns true of one or more Tasks is either processing a request or has a
    # request waiting to be processed on it's input queue.
    # @return [true|false] the busy state across all Tasks
    def self.busy?
      @@flows.each_value { |f| return true if f.busy? }
      false
    end

    # Calls the stop() method on all Tasks.
    def self.stop()
      @@flows.each_value { |f| f.stop() }
    end

    # Calls the step() method one Task that is stopped and has an item in the
    # queue. The Tasks with the highest backed_up() value is selected.
    def self.step()
      max = 0.0
      best = nil
      walk_tasks() do |t|
        if Task::STOPPED == t.state
          bu = t.backed_up()
          if max < bu
            best = t
            max = bu
          end
        end
      end
      best.step() unless best.nil?
      best
    end

    # Calls the start() method on all Tasks.
    def self.start()
      @@flows.each_value { |f| f.start() }
    end

    # Wakes up all the Tasks in the Flow.
    def self.wakeup()
      @@flows.each_value { |f| f.wakeup() }
    end

    # Wakes up all the Tasks in the Flow and waits for the system to become idle
    # before returning.
    def self.flush()
      wakeup()
      @@flows.each_value { |f| f.flush() }
      while busy?
        sleep(0.2)
      end
    end

    # Sets the state of all Tasks recursively. This should not be called
    # directly.
    def self.state=(s)
      @@flows.each_value do |f|
        f.state = s
      end
    end

    # Shuts down all Tasks.
    # @param flush_first [true|false] flag indicating shutdown should occur after the system becomes idle
    def self.shutdown(flush_first=false)
      # block all tasks first so threads can empty queues
      @@flows.each_value do |f|
        f.state = Task::BLOCKED
      end
      # shutdown and wait for queues to empty if necessary
      @@flows.each_value do |f|
        f.shutdown(flush_first)
      end
      @@flows = {}
    end

    # Clears out all Tasks and Flows and resets the object back to a empty state.
    def self.clear()
      shutdown()
      @@flows = {}
      _clear()
    end

    # Returns the default log level.
    # @return [Fixnum] the default log level which is one of the Logger::Severity values.
    def self.log_level()
      @@log_level
    end

    # Sets the default log level.
    # @param level [Fixnum] Logger::Severity to set the default log level to
    def self.log_level=(level)
      @@log_level = level unless level < Logger::Severity::DEBUG || Logger::Severity::FATAL < level
      @log.receive(:severity, Box.new(@@log_level)) unless @log.nil?
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
      @@flows.each_value { |f|
        lines << f.describe(detail, indent + 2)
      }
      lines << i + "}"
      lines.join("\n")
    end

  end # Env
end # OFlow
