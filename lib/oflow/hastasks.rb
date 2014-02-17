
module OFlow

  # Provides the ability to have Tasks and Flows.
  module HasTasks
    
    # Initializes the tasks attribute.
    def init_tasks()
      @tasks = {}
    end

    # Creates a Flow and yield to a block with the newly create Flow. Used to
    # contruct Flows.
    # @param name [Symbol|String] base name for the Flow
    # @param options [Hash] optional parameters
    # @param block [Proc] block to yield to with the new Flow instance
    # @return [Flow] new Flow
    def flow(name, options={}, &block)
      f = Flow.new(self, name, options)
      @tasks[f.name] = f
      yield(f) if block_given?
      f.resolve_all_links()
      # Wait to validate until at the top so up-links don't fail validation.
      if Env == self
        f.validate() 
        f.start()
      end
      f
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
      @links.each_value { |lnk|
        set_link_target(lnk) if lnk.target.nil?
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
      return self if :flow == name
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

  end # HasTasks
end # OFlow
