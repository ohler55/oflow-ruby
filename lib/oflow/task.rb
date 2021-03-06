
module OFlow

  # The Task class provides the asynchronous functionality for the system. Each
  # Task has it's own thread and receives requests as an operation and Box of
  # data by the receive() method. The request is put on a queue and popped off
  # one at a time and handed to an Actor associatesd with the Task.
  class Task

    include HasErrorHandler
    include HasLog

    # The name.
    attr_reader :name

    attr_accessor :bounds
    attr_accessor :shape
    attr_accessor :color

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
    # @param flow [Flow] Flow containing the Task
    # @param name [name] Task base name
    # @param actor_class [Class] _class Class of the Actor to create
    # @param options [Hash] additional options for the Task or Actor
    def initialize(flow, name, actor_class, options={})
      @flow = flow
      @name = name.to_sym
      @state = STARTING
      @bounds = nil # [x, y, w, h] as fixnums
      @color = nil  # [r, g, b] as floats
      @shape = nil  # Rectangle is the default
      @queue = []
      @req_mutex = Mutex.new()
      @req_thread = nil
      @step_thread = nil
      @waiting_thread = nil
      @req_timeout = 0.0
      @max_queue_count = nil
      @current_req = nil
      @proc_cnt = 0
      @loop = nil
      @links = {}
      @log = nil
      @error_handler = nil

      set_options(options)

      info("Creating actor #{actor_class} with options #{options}.")
      @actor = actor_class.new(self, options)
      raise Exception.new("#{actor} does not respond to the perform() method.") unless @actor.respond_to?(:perform)

      @state = options.fetch(:state, RUNNING)

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
                next
              end
              @req_mutex.synchronize {
                req = @queue.pop()
              }
              @req_thread.wakeup() unless @req_thread.nil?

              @current_req = req
              begin
                if debug?
                  debug("perform(#{req.op}, #{req.box.nil? ? '<nil>' : req.box})")
                else
                  info("perform(#{req.op})")
                end
                @actor.perform(req.op, req.box) unless req.nil?
              rescue Exception => e
                handle_error(e)
              end
              @proc_cnt += 1
              @current_req = nil
              if STEP == @state
                @step_thread.wakeup() unless @step_thread.nil?
                @state = STOPPED
              end
            elsif STOPPED == @state
              sleep(1.0)
            end
          rescue Exception => e
            puts "*** #{full_name} #{e.class}: #{e.message}"
            @current_req = nil
            # TBD Env.rescue(e)
          end
        end
      end
    end

    # Creates a Link identified by the label that has a target Task and
    # operation.

    # @param label [Symbol|String] identifer of the Link
    # @param target [Symbol|String] identifer of the target Task
    # @param op [Symbol|String] operation to perform on the target Task
    # @param flow_name [Symbol|String] parent flow name to find the target task in or nil for this parent
    def link(label, target, op, flow_name=nil)
      label = label.to_sym unless label.nil?
      op = op.to_sym unless op.nil?
      flow_name = flow_name.to_sym unless flow_name.nil?
      raise ConfigError.new("Link #{label} already exists.") unless @links[label].nil?
      @links[label] = Link.new(flow_name, target.to_sym, op)
    end

    # Similar to a full file path. The full_name described the containment of
    # the named item.
    # @return [String] full name of item
    def full_name()
      if @flow.nil?
        ':' + @name.to_s
      else
        @flow.full_name() + ':' + @name.to_s
      end
    end

    # Returns a log Task by looking for that Task as an attribute and then in
    # the parent Flow.
    # @return [Task] log Task.
    def log()
      return @log unless @log.nil?
      @flow.log()
    end

    # Returns an error handler Task by looking for that Task as an attribute and then in
    # the parent Flow.
    # @return [Task] error handler Task.
    def error_handler()
      return @error_handler unless @error_handler.nil?
      @flow.error_handler()
    end

    # Returns the state of the Task as a String.
    # @return [String] String representation of the state
    def state_string()
      ss = 'UNKNOWN'
      case @state
      when STARTING
        ss = 'STARTING'
      when STOPPED
        ss = 'STOPPED'
      when RUNNING
        ss = 'RUNNING'
      when CLOSING
        ss = 'CLOSING'
      when BLOCKED
        ss = 'BLOCKED'
      when STEP
        ss = 'STEP'
      end
      ss
    end

    # Returns a String that describes the Task.
    # @param detail [Fixnum] higher values result in more detail in the description
    # @param indent [Fixnum] the number of spaces to indent the description
    def describe(detail=0, indent=0)
      i = ' ' * indent
      lines = ["#{i}#{name} (#{actor.class}) {"]
      @links.each { |local,link|
        if link.flow_name.nil?
          lines << "  #{i}#{local} => :#{link.target_name}:#{link.op}"
        else
          lines << "  #{i}#{local} => #{link.flow_name}:#{link.target_name}:#{link.op}"
        end
      }
      if 1 <= detail
        lines << "  #{i}queued: #{queue_count()} (#{busy? ? 'busy' : 'idle'})"
        lines << "  #{i}state: #{state_string()}"
        @actor.options.each do |key,value|
          lines << "  #{i}#{key} = #{value} (#{value.class})"
        end
        if 2 <= detail
          lines << "  #{i}processing: #{@current_req.describe(detail)}" unless @current_req.nil?
          # Copy queue so it doesn't change while working with it and don't
          # block the queue. It is okay for the requests to be stale as it is
          # for a display that will be out of date as soon as it is displayed.
          reqs = []
          @req_mutex.synchronize {
            reqs = Array.new(@queue)
          }
          lines << "  #{i}queue:"
          reqs.each do |req|
            lines << "    #{i}#{req.describe(detail)}"
          end
        end
      end
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
    # @return [Fixnum] a measure of how backed up a Task is
    def backed_up()
      cnt = @queue.size() + (@current_req.nil? ? 0 : 1)
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
      !@current_req.nil? || !@queue.empty? || @actor.busy?
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
    # @param max_wait [Float|Fixnum] _wait maximum time to wait for the step to complete
    def step(max_wait=5)
      return nil if @loop.nil?
      return nil if STOPPED != @state || @queue.empty?
      @state = STEP
      @step_thread = Thread.current
      @loop.wakeup()
      sleep(max_wait)
      @step_thread = nil
      self
    end

    # Wakes up the Task if it has been stopped or if Env.shutdown() has been called.
    def wakeup()
      # don't wake if the task is currently processing
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

    # Waits for all processing to complete before returning.
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

    # The current state of the Task.
    def state=(s)
      @state = s
    end

    # The expected inputs the Task supports or nil if not implemented.
    def inputs()
      @actor.inputs()
    end

    # The expected outputs the Task supports or nil if not implemented.
    def outputs()
      @actor.outputs()
    end

    # Creates a Request and adds it to the queue.
    # @param op [Symbol] operation to perform
    # @param box [Box] contents or data for the request
    def receive(op, box)
      if debug?
        debug("receive(#{op}, #{box.nil? ? '<nil>' : box}) #{state_string}")
      else
        info("receive(#{op})")
      end
      return if CLOSING == @state

      raise BlockedError.new() if BLOCKED == @state

      box = box.receive(full_name, op) unless box.nil?
      # Special case for starting state so that an Actor can place an item on
      # the queue before the loop is started.
      if @loop.nil? && STARTING != @state # no thread task
        begin
          @actor.perform(op, box)
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

    # Sends a message to another Task or Flow.
    # @param dest [Symbol] identifies the link that points to the destination Task or Flow
    # @param box [Box] contents or data for the request
    def ship(dest, box)
      box.freeze() unless box.nil?
      link = resolve_link(dest)
      raise LinkError.new(dest) if link.nil? || link.target.nil?
      if debug?
        debug("shipping #{box} to #{link.target_name}:#{link.op}")
      else
        info("shipping to #{link.target_name}:#{link.op}")
      end
      link.target.receive(link.op, box)
      link
    end

    # Processes the initialize() options. Subclasses should call super.
    # @param options [Hash] options to be used for initialization
    # @option options [Fixnum] :max_queue_count maximum number of requests
    #         that can be queued before backpressure is applied to the caller.
    # @option options [Float] :request_timeout timeout in seconds to wait
    #         before raising a BusyError if the request queue is too long.
    def set_options(options)
      @max_queue_count = options.fetch(:max_queue_count, @max_queue_count)
      @req_timeout = options.fetch(:request_timeout, @req_timeout).to_f
    end
    
    def set_option(key, value)
      case key.to_sym()
      when :max_queue_count
        @max_queue_count = value.to_i
      when :request_timeout
        @req_timeout = value.to_f
      else
        @actor.set_option(key, value)
      end
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

    # Resolves all links. Called by the system.
    def resolve_all_links()
      @links.each_value { |lnk|
        set_link_target(lnk) if lnk.target.nil?
      }
    end

    # Attempts to find and resolve the Link identified by the label. Resolving a
    # Link uses the target identifier to find the target Task and save that in
    # the Link.
    # @param label [Symbol|String] identifer of the Link
    # @return [Link] returns the Link for the label
    def resolve_link(label)
      label = label.to_sym unless label.nil?
      lnk = @links[label] || @links[nil]
      return nil if lnk.nil?
      set_link_target(lnk) if lnk.target.nil?
      lnk
    end

    # Sets the target Task for a Link.
    # @param lnk [Link] Link to find the target Task for.
    def set_link_target(lnk)
      f = @flow
      f = @flow.env.find_flow(lnk.flow_name) unless lnk.flow_name.nil?
      raise ConfigError.new("Flow '#{lnk.flow_name}' not found.") if f.nil?
      lnk.instance_variable_set(:@target, f.find_task(lnk.target_name))
    end

    # Attempts to find the Link identified by the label.
    # @param label [Symbol|String] identifer of the Link
    # @return [Link] returns the Link for the label
    def find_link(label)
      label = label.to_sym unless label.nil?
      @links[label] || @links[nil]
    end

    # Returns the Links.
    # @return [Hash] Hash of Links with the keys as Symbols that are the labels of the Links.
    def links()
      @links
    end

    def has_links?()
      !@links.nil? && !@links.empty?
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

      def describe(detail=3)
        if @box.nil?
          "#{@op}()"
        elsif 2 >= detail
          @op
        elsif 3 >= detail || @box.tracker.nil?
          "#{@op}(#{@box.contents})"
        else
          "#{@op}(#{@box.contents}) #{@box.tracker}"
        end
      end

    end # Request

  end # Task
end # OFlow
