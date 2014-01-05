
module OFlow

  class Flow < Task

    def initialize()
      super(FlowActor)
    end

    def receive(op, box)
      # TBD pass on to inner task
    end

    class FlowActor < Actor
      def initialize(task)
        super
      end

      def inputs()
        # TBD
      end

      def outputs()
        # TBD
      end

      def perform(task, op, box)
      end

    end # FlowActor

  end # Flow
end # OFlow
