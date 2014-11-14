
module OFlow

  # The Class used to managing interactions between Tasks and sub-Flows. It can
  # be thought of as a container for Tasks where the Flow keeps track of the
  # Links between the Tasks.
  class Flow

    include HasErrorHandler
    include HasLog

    # The name.
    attr_reader :name

    # Create a new Flow.
    # @param env [Env] Env containing the Flow
    # @param name [name] Flow base name
    # @param options [Hash] additional options for the Flow
    def initialize(env, name, options)
      @name = name.to_sym
      @tasks = {}
      @inputs = {}
    end

    # Similar to a full file path. The full_name described the containment of
    # the named item.
    # @return [String] full name of item
    def full_name()
      @name.to_s
    end

    # Creates a Task and yield to a block with the newly create Task. Used to
    # configure Tasks.
    # @param name [Symbol|String] base name for the Task
    # @param actor_class [Class] Class to create an Actor instance of
    # @param options [Hash] optional parameters
    # @param block [Proc] block to yield to with the new Task instance
    # @return [Task] new Task
    def task(name, actor_class, options={}, &block)
      has_state = options.has_key?(:state)
      options[:state] = Task::STOPPED unless has_state
      t = Task.new(self, name, actor_class, options)
      @tasks[t.name] = t
      yield(t) if block_given?
      t
    end

    # Validates the container by verifying all links on a task have been set to
    # a valid destination and that destination has been resolved.
    # @raise [ValidateError] if there is an error in validation
    def validate()
      # collects errors and raises all errors at once if there are any
      errors = _validation_errors()
      raise ValidateError.new(errors) unless errors.empty?
    end

    # Returns an Array of validation errors.
    def _validation_errors()
      errors = []
      @tasks.each_value { |t| errors += t._validation_errors() }
      errors
    end

    # Resolves all the Links on all the Tasks and Flows being managed as well as
    # any Links in the instance itself.
    def resolve_all_links()
      @inputs.each_value { |lnk|
        if lnk.target.nil?
          task = find_task(lnk.target_name)
          lnk.instance_variable_set(:@target, task)
        end
      }
      @tasks.each_value { |t|
        t.resolve_all_links()
      }
    end

    # Iterates over each Task and yields to the provided block with each Task.
    # @param blk [Proc] Proc to call on each iteration
    def each_task(&blk)
      @tasks.each { |name,task| blk.yield(task) }
    end

    # Performs a recursive walk over all Tasks and yields to the provided block
    # for each. Flows are followed recusively.
    # @param tasks_only [true|false] indicates on Tasks and not Flows are yielded to
    # @param blk [Proc] Proc to call on each iteration
    def walk_tasks(tasks_only=true, &blk)
      @tasks.each_value do |t|
        if t.is_a?(Task)
          blk.yield(t)
        else
          blk.yield(t) unless tasks_only
          t.walk_tasks(tasks_only, &blk)
        end
      end
    end

    # Locates and return a Task with the specified name.
    # @param name [String] name of the Task
    # @return [Task|nil] the Task with the name specified or nil
    def find_task(name)
      name = name.to_sym unless name.nil?
      @tasks[name]
    end

    # Locates and return a Task with the specified full name.
    # @param name [String] full name of the Task
    # @return [Task|nil] the Task with the name specified or nil
    def locate(name)
      name = name[1..-1] if name.start_with?(':')
      name = name[0..-2] if name.end_with?(':')
      path = name.split(':')
      _locate(path)
    end

    def _locate(path)
      t = @tasks[path[0].to_sym]
      return t if t.nil? || 1 == path.size
      t._locate(path[1..-1])
    end

    # Returns the number of active Tasks.
    def task_count()
      @tasks.size
    end

    # Returns the sum of all the requests in all the Tasks's queues.
    # @return [Fixnum] total number of items waiting to be processed
    def queue_count()
      cnt = 0
      @tasks.each_value { |task| cnt += task.queue_count() }
      cnt
    end

    # Returns true of one or more Tasks is either processing a request or has a
    # request waiting to be processed on it's input queue.
    # @return [true|false] the busy state across all Tasks
    def busy?
      @tasks.each_value { |task| return true if task.busy? }
      false
    end

    # Calls the stop() method on all Tasks.
    def stop()
      @tasks.each_value { |task| task.stop() }
    end

    # Calls the step() method one Task that is stopped and has an item in the
    # queue. The Tasks with the highest backed_up() value is selected.
    def step()
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
    def start()
      @tasks.each_value { |task| task.start() }
    end

    # Wakes up all the Tasks in the Flow.
    def wakeup()
      @tasks.each_value { |t| t.wakeup() }
    end

    # Wakes up all the Tasks in the Flow and waits for the system to become idle
    # before returning.
    def flush()
      wakeup()
      @tasks.each_value { |t| t.flush() }
      while busy?
        sleep(0.2)
      end
    end

    # Sets the state of all Tasks recursively. This should not be called
    # directly.
    def state=(s)
      @tasks.each_value do |task|
        task.state = s
      end
    end

    # Shuts down all Tasks.
    # @param flush_first [true|false] flag indicating shutdown should occur after the system becomes idle
    def shutdown(flush_first=false)
      # block all tasks first so threads can empty queues
      @tasks.each_value do |task|
        task.state = Task::BLOCKED
      end
      # shutdown and wait for queues to empty if necessary
      @tasks.each_value do |task|
        task.shutdown(flush_first)
      end
      @tasks = {}
    end

    # Clears out all Tasks and Flows and resets the object back to a empty state.
    def clear()
      shutdown()
      @tasks = {}
      _clear()
    end

    # Creates a Link identified by the label that has a target Task and
    # operation.
    # @param label [Symbol|String] identifer of the Link
    # @param target [Symbol|String] identifer of the target Task
    # @param op [Symbol|String] operation to perform on the target Task
    def input(label, target, op)
      label = label.to_sym unless label.nil?
      op = op.to_sym unless op.nil?
      raise ConfigError.new("Input #{label} already exists.") unless @inputs[label].nil?
      @inputs[label] = Link.new(target.to_sym, op)
    end

    # Attempts to find and resolve the input identified by the label. Resolving
    # a input uses the target identifier to find the target Task and saves that
    # in the Link.
    # @param label [Symbol|String] identifer of the Input
    # @return [Link] returns the input for the label
    def resolve_link(label)
      label = label.to_sym unless label.nil?
      lnk = @inputs[label] || @links[nil]
      return nil if lnk.nil?
      if lnk.target.nil?
        task = find_task(lnk.target_name)
        lnk.instance_variable_set(:@target, task)
      end
      lnk
    end

    # Receive a request which is redirected to a Linked target Task.
    # @param input [Symbol] identifies the link that points to the destination Task or Flow
    # @param box [Box] contents or data for the request
    def receive(input, box)
      box = box.receive(full_name, input)
      lnk = find_input(input) # find input
      raise LinkError.new(op) if lnk.nil? || lnk.target.nil?
      lnk.target.receive(lnk.op, box)
    end

    # Attempts to find the input identified by the label.
    # @param label [Symbol|String] identifer of the input
    # @return [Link] returns the input Link for the label
    def find_input(label)
      label = label.to_sym unless label.nil?
      @inputs[label] || @inputs[nil]
    end

    # Returns true if the Flow has a Link identified by the op.
    # @param op [Symbol] identifies the Link in question
    def has_input(op)
      !find_input(op).nil?
    end

    # Returns the input Links.
    # @return [Hash] Hash of Links with the keys as Symbols that are the labels of the Links.
    def inputs()
      @inputs
    end

    def has_inputs?()
      !@inputs.nil? && !@inputs.empty?
    end

    # Returns a String describing the Flow.
    # @param detail [Fixnum] higher values result in more detail in the description
    # @param indent [Fixnum] the number of spaces to indent the description
    def describe(detail=0, indent=0)
      i = ' ' * indent
      lines = ["#{i}#{name} (#{self.class}) {"]
      @tasks.each_value { |t|
        lines << t.describe(detail, indent + 2)
      }
      @inputs.each { |local,link|
        lines << "  #{i}#{local} => #{link.target_name}:#{link.op}"
      }
      lines << i + "}"
      lines.join("\n")
    end

    def _clear()
    end

  end # Flow
end # OFlow
