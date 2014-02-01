
module OFlow
  module Actors

    class Relay < Actor

      def initialize(task, options)
        super
      end

      def perform(task, op, box)
        task.ship(op, box)
      end

      def with_own_thread()
        false
      end

    end # Relay
  end # Actors
end # OFlow
