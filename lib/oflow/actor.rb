
module OFlow

  # Actors provide the custom functionality for Tasks. Each Task creates an
  # instance of some Actor. Actors are not shared between Tasks and each can be
  # assure that the data they operate on is their own.
  class Actor

    # The enclosing task.
    attr_reader :task

    # Creates a new instance.
    # @param task [Task] enclosing Task
    # @param options [Hash] additional options
    def initialize(task, options)
      @task = task
    end
    
    # Perform the primary functions for the Actor.
    # @param op [Symbol] operation to perform
    # @param box [Box] contents or data for the operation
    def perform(op, box)
    end

    # Returns whether the Actor should have it's own thread or not. In almost
    # all cases the Actor should have it's own thread. The exception is when the
    # action is trivial such as a relay.
    # @return [true|false] indicator of whether a new thread should be created.
    def with_own_thread()
      true
    end

    # Return array of Specs.
    # @return [Array] Array of Specs.
    def inputs()
      nil
    end

    # Return array of Specs.
    # @return [Array] Array of Specs.
    def outputs()
      nil
    end

    # Return any options that should be displayed as part of a Task.describe().
    # @return [Hash] Hash of options with String keys.
    def options()
      {}
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

