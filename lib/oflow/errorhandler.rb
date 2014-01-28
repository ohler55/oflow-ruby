
module OFlow

  class ErrorHandler < Actor

    def initialize(task, options={})
      super
    end

    def perform(task, op, box)
      contents = box.contents
      return task.error(contents.to_s) unless contents.is_a?(Array)
      e, where = contents
      task.error(e.to_s) unless e.is_a?(Exception)
      msg = ["#{e.class}: #{e.message}"]
      e.backtrace.each { |line| msg << ('    ' + line) }
      task.log_msg(:error, msg.join("\n"), where)
    end

    def with_own_thread()
      false
    end

  end # ErrorHandler
end # OFlow
