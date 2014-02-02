
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
        @start = Time.now() if @start.nil?
        @pending = @start
        super
        task.receive(:init, nil)
      end

      # The loop in the Task containing this Actor is the thread used for the
      # timer. Mostly the perform() method sleeps but it will be woken when a
      # new request is placed on the Task queue so it exits if there is a
      # request on the queue even if it has not triggered a ship() know that it
      # will be re-entered.
      def perform(task, op, box)
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

          if @pending <= now
            @count += 1
            now = Time.now()
            tracker = @with_tracker ? Tracker.new(@label) : nil
            box = Box.new([@label, @count, now.utc()], tracker)
            task.links.each_key { |key| task.ship(key, box) }
            if @period.nil? || @period == 0
              @pending = now
            else
              @pending += period
            end
          end
          # If there is a request waiting then return so it can be handled. It
          # will come back here to allow more timer processing.
          return if 0 < task.queue_count()

          now = Time.now()
          if now < @pending
            wait_time = @pending - now
            wait_time = MAX_SLEEP if MAX_SLEEP < wait_time
            sleep(wait_time)
          end
        end
      end

      def set_options(options)
        @start = options[:start]
        @stop = options[:stop]
        @period = options[:period]
        @repeat = options[:repeat]
        @label = options[:label]
        @with_tracker = options[:with_tracker]
        # TBD check values for type and range
      end

    end # Timer
  end # Actors
end # OFlow
