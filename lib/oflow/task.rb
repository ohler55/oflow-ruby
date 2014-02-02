
module OFlow

  # The Task class provides the asynchronous functionality for the system. Each
  # Task has it's own thread and receives requests as an operation and Box of
  # data by the receive() method. The request is put on a queue and popped off
  # one at a time and handed to an Actor associatesd with the Task.
  class Task
    include HasName
    include HasLinks
    include HasErrorHandler
    include HasLog

    # value of @state that indicates the Task is being created.
    STARTING = 0
    # value of @state that indicates the Task is not currently processing requests
    STOPPED  = 1
    # value of @state that indicates the Task is currently ready to process requests
    RUNNING  = 2
    # value of @state that indicates the Task is shutting down
    CLOSING  = 3
    # value of @state that indicates the Task is not receiving new requests.
    BLOCKED  = 4
    # value of @state that indicates the Task is processing one request and will
    # stop after that processing is complete
    STEP     = 5

    # The current processing state of the Task
    attr_reader :state
    # the Actor
    attr_reader :actor

    # A Task is initialized by specifying a class to create an instance of.
    def initialize(flow, name, actor_class, options={})
      @state = STARTING
      @queue = []
      @req_mutex = Mutex.new()
      @req_thread = nil
      @step_thread = nil
      @waiting_thread = nil
      @req_timeout = 0.0
      @max_queue_count = nil
      @busy = false
      @proc_cnt = 0
      @loop = nil

      init_name(flow, name)
      init_links()
      set_options(options)

      @actor = actor_class.new(self, options)
      raise Exception.new("#{actor} does not respond to the perform() method.") unless @actor.respond_to?(:perform)

      @state = RUNNING
      return unless @actor.with_own_thread()

      @loop = Thread.start(self) do |me|
        Thread.current[:name] = me.full_name()
        while CLOSING != @state
          begin
            if RUNNING == @state || STEP == @state || BLOCKED == @state
              req = nil
              if @queue.empty?
                @waiting_thread.wakeup() unless @waiting_thread.nil?
                sleep(1.0)
              else
                @req_mutex.synchronize {
                  req = @queue.pop()
                }
                @req_thread.wakeup() unless @req_thread.nil?
              end
              @busy = true
              begin
                @actor.perform(self, req.op, req.box) unless req.nil?
              rescue Exception => e
                handle_error(e)
              end
              @proc_cnt += 1
              @busy = false
              if STEP == @state
                @step_thread.wakeup() unless @step_thread.nil?
                @state = STOPPED
              end
            elsif STOPPED == @state
              sleep(1.0)
            end
          rescue Exception => e
            @busy = false
            # TBD Env.rescue(e)
          end
        end
      end
    end

    def state_string()
      ss = 'UNKNOWN'
      case @state
      when STOPPED
        ss = 'STOPPED'
      when RUNNING
        ss = 'RUNNING'
      when CLOSING
        ss = 'CLOSING'
      when STEP
        ss = 'STEP'
      end
      ss
    end

    def describe(indent=0)
      i = ' ' * indent
      lines = ["#{i}#{name} (#{actor.class}) {"]
      @links.each { |local,link|
        lines << "  #{i}#{local} => #{link.target_name}:#{link.op}"
      }
      lines << i + "}"
      lines.join("\n")
    end


    # Returns the number of requests on the queue.
    # @return [Fixnum] number of queued requests
    def queue_count()
      @queue.length
    end

    # Returns a score indicating how backed up the queue is. This is used for
    # selecting an Actor when stepping from the Inspector.
    def backed_up()
      cnt = @queue.size()
      return 0 if 0 == cnt
      if @max_queue_count.nil? || 0 == @max_queue_count
        cnt = 80 if 80 < cnt
        cnt
      else
        cnt * 100 / @max_queue_count
      end
    end

    # Returns the true if any requests are queued or a request is being processed.
    # @return [true|false] true if busy, false otherwise
    def busy?()
      @busy || !@queue.empty?
    end

    # Returns the default timeout for the time to wait for the Task to be
    # ready to accept a request using the receive() method.
    # @return [Float] current timeout for the receive() method
    def request_timeout()
      @req_timeout
    end

    # Returns the maximum number of requests allowed on the normal processing
    # queue. A value of nil indicates there is no limit.
    # @return [NilClass|Fixnum] maximum number of request that can be queued
    def max_queue_count()
      @max_queue_count
    end

    # Returns the total number of requested processed.
    # @return [Fixnum] number of request processed
    def proc_count()
      @proc_cnt
    end

    # Causes the Actor to stop processing any more requests after the current
    # request has finished.
    def stop()
      @state = STOPPED
    end

    # Causes the Task to process one request and then stop. The max_wait is
    # used to avoid getting stuck if the processing takes too long.
    # @param [Float|Fixnum] max_wait maximum time to wait for the step to complete
    def step(max_wait=5)
      return if @loop.nil?
      @state = STEP
      @step_thread = Thread.current
      @loop.wakeup()
      sleep(max_wait)
      @step_thread = nil
    end

    # Wakes up the Task if it has been stopped or if Env.shutdown() has been called.
    def wakeup()
      @loop.wakeup() unless @loop.nil?
    end

    # Restarts the Task's processing thread.
    def start()
      @state = RUNNING
      @loop.wakeup() unless @loop.nil?
    end

    # Closes the Task by exiting the processing thread. If flush is true then
    # all requests in the queue are processed first.
    def shutdown(flush_first=false)
      return if @loop.nil?
      if flush_first
        @state = BLOCKED
        flush()
      end
      @state = CLOSING
      begin
        # if the loop has already exited this will raise an Exception that can be ignored
        @loop.wakeup()
      rescue
        # ignore
      end
      @loop.join()
    end

    def flush()
      return if @loop.nil?
      @waiting_thread = Thread.current
      begin
        @loop.wakeup()
      rescue
        # ignore
      end
      while busy?
        sleep(2.0)
      end
      @waiting_thread = nil
    end

    def state=(s)
      # TBD anything that needs to be done when changing state?
      @state = s
    end

    def inputs()
      @actor.inputs()
    end

    def outputs()
      @actor.outputs()
    end

    def receive(op, box)
      raise BlockedError.new() if CLOSING == @state || BLOCKED == @state
      box = box.receive(full_name, op) unless box.nil?
      # Special case for starting state so that an Actor can place an item on
      # the queue before the loop is started.
      if @loop.nil? && STARTING != @state # no thread task
        begin
          @actor.perform(self, op, box)
        rescue Exception => e
          handle_error(e)
        end
        return
      end
      unless @max_queue_count.nil? || 0 == @max_queue_count || @queue.size() < @max_queue_count
        @req_thread = Thread.current
        sleep(timeout) unless @req_timeout.nil? || 0 == @req_timeout
        @req_thread = nil
        raise BusyError.new() unless @queue.size() < @max_queue_count
      end
      @req_mutex.synchronize {
        @queue.insert(0, Request.new(op, box))
      }
      @loop.wakeup() if RUNNING == @state
    end

    def ship(dest, box)
      link = resolve_link(dest)
      raise LinkError.new(dest) if link.nil? || link.target.nil?
      link.target.receive(link.op, box)
      link
    end

    # Processes the initialize() options. Subclasses should call super.
    # @param [Hash] options options to be used for initialization
    # @option options [Fixnum] :max_queue_count maximum number of requests
    #         that can be queued before backpressure is applied to the caller.
    # @option options [Float] :ask_timeout timeout in seconds to wait
    #         before raising a BusyError if the request queue is too long.
    def set_options(options)
      @max_queue_count = options.fetch(:max_queue_count, @max_queue_count)
      @req_timeout = options.fetch(:request_timeout, @req_timeout).to_f
    end
    
    def _validation_errors()
      errors = []
      @links.each_value { |lnk| _check_link(lnk, errors) }

      unless (outs = @actor.outputs()).nil?
        outs.each do |spec|
          if find_link(spec.dest).nil?
            errors << ValidateError::Problem.new(full_name, ValidateError::Problem::MISSING_ERROR, "Missing link for '#{spec.dest}'.")
          end
        end
      end
      errors
    end

    def has_input(op)
      ins = @actor.inputs()
      return true if ins.nil?
      op = op.to_sym unless op.nil?
      ins.each { |spec| return true if spec.op.nil? || spec.op == op }
      false
    end

    def _check_link(lnk, errors)
      if lnk.target.nil?
        errors << ValidateError::Problem.new(full_name, ValidateError::Problem::LINK_ERROR, "Failed to find task '#{lnk.target_name}'.")
        return
      end
      unless lnk.target.has_input(lnk.op)
        errors << ValidateError::Problem.new(full_name, ValidateError::Problem::INPUT_ERROR, "'#{lnk.op}' not allowed on '#{lnk.target.full_name}'.")
        return
      end

      # TBD
      # Verify target has link.op as input if input is specified.

    end

    def resolve_all_links()
      @links.each_value { |lnk|
        set_link_target(lnk) if lnk.target.nil?
      }
    end

    private

    # Internal class used to store information about asynchronous method
    # invocations.
    class Request
      attr_accessor :op
      attr_accessor :box

      def initialize(op, box)
        @op = op
        @box = box
      end
    end # Request

    class Link
      attr_reader :name
      attr_reader :task
      attr_reader :op

      def initialize(name, task, op)
        @name = name
        @task = task
        @op = op
      end

    end # Link

  end # Task
end # OFlow
