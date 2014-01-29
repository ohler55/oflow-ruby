
module OFlow
  module Test
    class ActorWrap

      attr_reader :actor
      attr_accessor :name

      # Array of Actions. Log entries appear with a destination of :log.
      attr_reader :history

      def initialize(name, actor_class, options={})
        @name = name
        @actor = actor_class.new(self, options)
        @history = []
      end

      def reset()
        @history = []
      end
      
      def full_name()
        ":test:#{@name}"
      end

      # Calls perform on the actor instance
      def receive(op, box)
        @actor.perform(self, op, box)
      end

      # Task API that adds entry to history.
      def ship(dest, box)
        @history << Action.new(dest, box)
      end

      def log_msg(level, msg, fn)
        @history << Action.new(:log, Box.new([level, msg, fn]))
      end

      def debug(msg)
        log_msg(:debug, msg, full_name())
      end

      def info(msg)
        log_msg(:info, msg, full_name())
      end

      def error(msg)
        log_msg(:error, msg, full_name())
      end

      def warn(msg)
        log_msg(:warn, msg, full_name())
      end

      def fatal(msg)
        log_msg(:fatal, msg, full_name())
      end

    end # ActorWrap
  end # Test
end # OFlow
