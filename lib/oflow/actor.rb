
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

    # Return array of Specs.
    def inputs()
      nil
    end

    # Return array of Specs.
    def outputs()
      nil
    end

    class Spec
      attr_reader :op
      attr_reader :type

      def initialize(op, type)
        if op.nil? || op.is_a?(Symbol)
          @op = op
        else
          @op = op.to_sym
        end
        @type = type
      end

      alias dest op

      def to_s()
        "Spec{op: #{@op}, type: #{@type}}"
      end
      alias inspect to_s

    end # Spec

  end

end # OFlow

