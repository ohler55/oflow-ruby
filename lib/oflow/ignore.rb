
module OFlow

  class Ignore < Actor

    def initialize(task, options)
      super
    end

    def perform(task, op, box)
      # ignore
    end

    def with_own_thread()
      false
    end

  end # Ignore

end # OFlow
