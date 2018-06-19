
require 'date'

require 'logger'

module OFlow
  module Actors

    class Timer < Actor

      MAX_SLEEP = 1.0

      # When to trigger the first event. nil means start now.
      attr_reader :start
      # The stop time. If nil then there is not stopping unless the repeat limit
      # kicks in.
      attr_reader :stop
      # How long to wait between each trigger. nil indicates as fast as possible,
      attr_reader :period
      # How many time to repeat before stopping. nil mean go forever.
      attr_reader :repeat
      # Label for the Tracker is used and for trigger content.
      attr_reader :label
      # The number of time the timer has fired or shipped.
      attr_reader :count
      # Boolean flag indicating a tracker should be added to the trigger content
      # if true.
      attr_reader :with_tracker
      # Time of next or pending trigger.
      attr_reader :pending

      def initialize(task, options={})
        @count = 0
        @pending = nil
        @stop = nil
        @period = nil
        @repeat = nil
        set_options(options)
        @pending = @start
        super
        task.receive(:init, nil)
      end

      # The loop in the Task containing this Actor is the thread used for the
      # timer. Mostly the perform() method sleeps but it will be woken when a
      # new request is placed on the Task queue so it exits if there is a
      # request on the queue even if it has not triggered a ship() know that it
      # will be re-entered.
      def perform(op, box)
        op = op.to_sym unless op.nil?
        case op
        when :stop
          set_stop(box.nil? ? nil : box.contents)
        when :start
          old = @start
          set_start(box.nil? ? nil : box.contents)
          @pending = @start if @start < old
        when :period
          old = @period
          set_period(box.nil? ? nil : box.contents)
          if old.nil? || @pending.nil? || @pending.nil?
            @pending = nil
          else
            @pending = @pending - old + @period
          end
        when :repeat
          set_repeat(box.nil? ? nil : box.contents)
        when :label
          set_label(box.nil? ? nil : box.contents)
        when :with_tracker
          set_with_tracker(box.nil? ? nil : box.contents)
        end
        while true
          now = Time.now()
          # If past stop time then it is done. A future change in options can
          # restart the timer.
          return if !@stop.nil? && @stop < now
          # Has repeat number been exceeded?
          return if !@repeat.nil? && @repeat <= @count
          # If there is nothing pending the timer has completed.
          return if @pending.nil?
          # If the Task is blocked or shutting down.
          return if Task::CLOSING == task.state || Task::BLOCKED == task.state

          if @pending <= now
            # Skip if stopped but do not increment counter.
            unless Task::STOPPED == task.state
              @count += 1
              now = Time.now()
              tracker = @with_tracker ? Tracker.create(@label) : nil
              box = Box.new([@label, @count, now.utc()], tracker)
              task.links.each_key do |key|
                begin
                  task.ship(key, box)
                rescue BlockedError
                  task.warn("Failed to ship timer #{box.contents} to #{key}. Task blocked.")
                rescue BusyError
                  task.warn("Failed to ship timer #{box.contents} to #{key}. Task busy.")
                end
              end
            end
            if @period.nil? || @period == 0
              @pending = now
            else
	      diff = now - @pending
              @pending += @period * diff.to_i/@period.to_i
	      @pending += @period if @pending <= now
            end
          end
          # If there is a request waiting then return so it can be handled. It
          # will come back here to allow more timer processing.
          return if 0 < task.queue_count()

          if Task::STOPPED == task.state
            sleep(0.1)
          else
            now = Time.now()
            if now < @pending
              wait_time = @pending - now
              wait_time = MAX_SLEEP if MAX_SLEEP < wait_time
              sleep(wait_time)
            end
          end
        end
      end

      def set_options(options)
        set_start(options[:start]) # if nil let start get set to now
        set_stop(options[:stop]) if options.has_key?(:stop)
        set_period(options[:period]) if options.has_key?(:period)
        set_repeat(options[:repeat]) if options.has_key?(:repeat)
        set_with_tracker(options[:with_tracker])
        @label = options[:label].to_s
      end

      def set_start(v)
        if v.is_a?(String)
          begin
            v = DateTime.parse(v).to_time
            v = v - v.gmtoff
          rescue Exception
            v = Time.now() + v.to_i
          end
        elsif v.is_a?(Numeric)
          v = Time.now() + v
        elsif v.nil?
          v = Time.now()
        elsif !v.kind_of?(Time) && !v.kind_of?(Date)
          raise ConfigError.new("Expected start to be a Time or Numeric, not a #{v.class}.")
        end
        @start = v
        @pending = @start
      end

      def set_stop(v)
        if v.is_a?(String)
          v = DateTime.parse(v).to_time
          v = v - v.gmtoff
        elsif v.is_a?(Numeric)
          v = Time.now() + v
        elsif !v.nil? && !v.kind_of?(Time) && !v.kind_of?(Date)
          raise ConfigError.new("Expected stop to be a Time or Numeric, not a #{v.class}.")
        end
        @stop = v
      end

      def set_period(v)
        p = 0.0
        if v.kind_of?(Numeric)
          p = v
        elsif v.is_a?(String)
          p = v.strip().to_f
        else
          raise ConfigError.new("Expected period to be a Numeric, not a #{v.class}.")
        end
        raise ConfigError.new("period must be greater than 0.0.") if 0.0 >= p
        @period = p
      end

      def set_repeat(v)
        r = nil
        if v.kind_of?(Fixnum)
          r = v
        elsif v.is_a?(String)
          r = v.strip().to_i
        elsif !v.nil?
          raise ConfigError.new("Expected repeat to be a Fixnum, not a #{v.class}.")
        end
        raise ConfigError.new("repeat must be greater than or equal 0.0 or nil") if !r.nil? && 0.0 >= r
        @repeat = r
      end

      def set_label(v)
        v = v.to_s unless v.nil?
        @label = v
      end

      def set_with_tracker(v)
        v = false if v.nil?
        unless true == v || false == v
          raise ConfigError.new("Expected with_tracker to be a boolean, not a #{v.class}.")
        end
        @with_tracker = v
      end

    end # Timer
  end # Actors
end # OFlow
