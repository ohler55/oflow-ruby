
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
          # TBD if no arg (or earlier than now) then stop now else set to new stop time
        when :start
          # TBD if stopped then start if no arg, if arg then set start time
        when :period
          # TBD
        when :repeat
          # TBD
        when :label
          # TBD
        when :with_tracker
          # TBD
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
                rescue BlockedError => e
                  task.warn("Failed to ship timer #{box.contents} to #{key}. Task blocked.")
                rescue BusyError => e
                  task.warn("Failed to ship timer #{box.contents} to #{key}. Task busy.")
                end
              end
            end
            if @period.nil? || @period == 0
              @pending = now
            else
              @pending += period
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
        now = Time.now()
        @start = options[:start]
        if @start.is_a?(Numeric)
          @start = now + @start
        elsif @start.nil?
          @start = Time.now()
        elsif !@start.kind_of?(Time) && !@start.kind_of?(Date)
          raise ConfigError.new("Expected start to be a Time or Numeric, not a #{@start.class}.")
        end
        @stop = options[:stop]
        if @stop.is_a?(Numeric)
          @stop = now + @stop
        elsif !@stop.nil? && !@stop.kind_of?(Time) && !@stop.kind_of?(Date)
          raise ConfigError.new("Expected stop to be a Time or Numeric, not a #{@stop.class}.")
        end
        @period = options[:period]
        unless @period.nil? || @period.kind_of?(Numeric)
          raise ConfigError.new("Expected period to be a Numeric, not a #{@period.class}.")
        end
        @repeat = options[:repeat]
        unless @repeat.nil? || @repeat.kind_of?(Fixnum)
          raise ConfigError.new("Expected repeat to be a Fixnum, not a #{@repeat.class}.")
        end
        @label = options[:label].to_s
        @with_tracker = options[:with_tracker]
        @with_tracker = false if @with_tracker.nil?
        unless true == @with_tracker || false == @with_tracker
          raise ConfigError.new("Expected with_tracker to be a boolean, not a #{@with_tracker.class}.")
        end
      end

    end # Timer
  end # Actors
end # OFlow
