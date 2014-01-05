
module OFlow

  class TaskTester < Task

    def initialize(actor_class)
      super
    end

    def receive(op, box)
      # TBD record or leave on stack
    end

  end # TaskTester
end # OFlow
