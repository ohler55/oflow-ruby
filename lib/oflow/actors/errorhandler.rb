
module OFlow
  module Actors

    # The default error handler.
    class ErrorHandler < Actor

      def initialize(task, options={})
        super
      end

      # Open the box, form a reasonable message, then log that message.
      # @param op [Symbol] ignores
      # @param box [Box] data associated with the error
      def perform(op, box)
        contents = box.contents
        return task.error(contents.to_s) unless contents.is_a?(Array)
        e, where = contents
        task.error(e.to_s) unless e.is_a?(Exception)
        msg = ["#{e.class}: #{e.message}"]
        e.backtrace.each { |line| msg << ('    ' + line) }
        task.log_msg(:error, msg.join("\n"), where)
      end

      # Handle error immediately.
      def with_own_thread()
        false
      end

    end # ErrorHandler
  end # Actors
end # OFlow
