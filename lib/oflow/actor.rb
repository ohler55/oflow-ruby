
module OFlow

  class Actor

    attr_reader :task

    def initialize(task, options)
      @task = task

    end

    def perform(task, op, box)
    end

    def with_own_thread()
      true
    end

  end

end # OFlow

