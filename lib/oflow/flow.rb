
module OFlow

  class Flow
    include HasTasks
    include HasLinks
    include HasName
    include HasErrorHandler
    include HasLog

    def initialize(flow, name, options)
      #super(flow, name, FlowActor, options)
      init_name(flow, name)
      init_tasks()
      init_links()
    end

    def receive(op, box)
      # TBD pass on to inner task
    end

    class FlowActor < Actor
      def initialize(task, options)
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
