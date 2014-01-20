
module OFlow

  module HasTasks
    
    def init_tasks()
      @tasks = {}
    end

    def flow(name, options={}, &block)
      f = Flow.new(self, name, options)
      @tasks[name] = f
      yield(f) if block_given?
      resolve_all_links()
      validate()
      prepare() if respond_to?(:prepare)
      f
    end

    def task(name, actor_class, options={}, &block)
      t = Task.new(self, name, actor_class, options)
      @tasks[t.name] = t
      yield(t) if block_given?
      t
    end

    def describe(indent=0)
      i = ' ' * indent
      if is_a?(Class) # Env
        lines = "#{i}#{self} {\n"
      elsif respond_to?(:name)
        lines = "#{i}#{name} (#{self.class}) {\n"
      else
        lines = "#{i}#{self.class} {\n"
      end
      @tasks.each_value { |t|
        lines += t.describe(indent + 2)
      }
      lines += i + "}\n"
      lines
    end

    # Validates the container by verifying all links on a task have been set to
    # a valid destination and that destination has been resolved.
    def validate()
      # collects errors and raises all errors at once if there are any
      errors = _validation_errors()
      raise ValidateError.new(errors) unless errors.empty?
    end

    def _validation_errors()
      errors = []
      @tasks.each_value { |t| errors += t._validation_errors() }
      errors
    end

    def resolve_all_links()
      @tasks.each_value { |t|
        t.resolve_all_links()
      }
    end


    # Iterates over each Task and yields to the provided block with each Task.
    # @param [Proc] blk Proc to call on each iteration
    def each_task(&blk)
      @tasks.each { |name,task| blk.yield(task) }
    end

    # Locates and return a Task with the specified name.
    # @param [String] name name of the Task
    # @return [Actor|NilClass] the Task with the name specified or nil
    def find_task(name)
      @tasks[name.to_sym]
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

    # Calls the start() method on all Tasks.
    def start()
      # TBD @@finish_thread = nil
      @tasks.each_value { |task| task.start() }
    end

    def wakeup()
      @tasks.each_value { |t| t.wakeup() }
    end

    def flush()
      wakeup()
      @tasks.each_value { |t| t.flush() }
      while busy?
        sleep(0.2)
      end
    end


    def state=(s)
      @tasks.each_value do |task|
        task.state = s
      end
    end

    # Shuts down all Tasks.
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

    def clear()
      shutdown()
      @tasks = {}
    end

  end # HasTasks
end # OFlow
