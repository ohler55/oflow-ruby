
module OFlow

  class Task

    def initialize(actor_class)
      # TBD ask class for
      # inputs (op, description, box type)
      # description
      # out (name, box type, description)
      # verify instances support the perform method
    end

    def receive(op, box)

    end

    def ship(dest, box)
      # TBD lookup dest to get a task and op, then call receive on that task
    end

  end # Task

end # OFlow
