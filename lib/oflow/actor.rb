
module OFlow

  class Actor

    attr_reader :task

    def initialize(task, options)
      @task = task

    end

    def perform(task, op, box)
    end

  end

end # OFlow

