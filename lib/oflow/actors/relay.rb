
module OFlow
  module Actors

    # Relays a shipment to another location. This is useful for creating aliases
    # for a Task.
    class Relay < Actor

      def initialize(task, options)
        super
      end

      def perform(op, box)
        task.ship(op, box)
      end

      def with_own_thread()
        false
      end

    end # Relay
  end # Actors
end # OFlow
