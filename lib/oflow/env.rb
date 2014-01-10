
module OFlow

  class Env
    attr_accessor :log
    attr_accessor :parent

    attr_reader :tasks

    def initialize(parent)
      @parent = parent
      @log = parent.log unless parent.nil?
      @tasks = {}
    end

    # Adds a Task to the Env.
    def add_task(task)
      @tasks[task.name] = task
    end

    # Iterates over each Task and yields to the provided block with each Task.
    # @param [Proc] blk Proc to call on each iteration
    def each_task(&blk)
      @@tasks.each { |name,task| blk.yield(task) }
    end

    # Locates and return a Task with the specified name.
    # @param [String] name name of the Task
    # @return [Actor|NilClass] the Task with the name specified or nil
    def find_Task(name)
      @tasks[name]
      nil
    end

    # Returns the number of active Tasks.
    def task_count()
      @tasks.size
    end

    # Shutsdown all Tasks and resets the logger to nil.
    def shutdown(flush_first=false)
      # block all tasks first so threads can empty queues
      @tasks.each_value do |task|
        task.state = BLOCKED
      end
      # shutdown and wait for queues to empty if necessary
      @tasks.each_value do |task|
        task.shutdown(flush_first)
      end
      @tasks = {}
      @log = nil
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



  end # Env
end # OFlow
