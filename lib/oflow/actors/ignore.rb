
module OFlow
  module Actors
    # Does nothing but can be used to terminate a Link to assure all output from
    # a Task terminate somewhere.
    class Ignore < Actor

      def initialize(task, options)
        super
      end

      def perform(op, box)
        # ignore
      end

      def with_own_thread()
        false
      end

    end # Ignore
  end # Actors
end # OFlow
