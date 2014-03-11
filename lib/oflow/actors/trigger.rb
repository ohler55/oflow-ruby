
module OFlow
  module Actors

    class Trigger < Actor
      
      # Label for the Tracker is used and for trigger content.
      attr_reader :label
      # Boolean flag indicating a tracker should be added to the trigger content
      # if true.
      attr_reader :with_tracker
      # The number of time the timer has fired or shipped.
      attr_reader :count

      def initialize(task, options)
        super
        @count = 0
        set_options(options)
      end
      
      def new_event()
        tracker = @with_tracker ? Tracker.create(@label) : nil
        Box.new({ source: task.full_name, label: @label, timestamp: Time.now.utc() }, tracker)
      end

      def set_options(options)
        set_with_tracker(options[:with_tracker])
        @label = options[:label].to_s
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

    end # Trigger
  end # Actors
end # OFlow
