
module OFlow

  # Provides functionality to find an error handler Task which is how error are
  # handled in the system. Each Flow or Task can have a different error
  # handler. If a Flow does not have an error handler the error bubbles up to
  # the next Flow until an error handler is found.
  module HasErrorHandler

    # Returns an error handler Task by checking for an @error_handler variable,
    # then looking for a Task with a base name of :error in itself or any of the
    # containing Flows.
    # @return [Task|nil] Task to handle errors
    def error_handler()
      return @error_handler if instance_variable_defined?(:@error_handler) && !@error_handler.nil?
      if instance_variable_defined?(:@flow)
        if @flow.respond_to?(:find_task)
          eh = @flow.find_task(:error)
          return eh unless eh.nil?
        end
        if @flow.respond_to?(:error_handler)
          eh = @flow.error_handler()
          return eh unless eh.nil?
        end
      end      
      nil
    end

    # Sets avaliable for handling errors.
    # @param t [Task|nil] Task for handling error or nil to unset
    def error_handler=(t)
      @error_handler = t
    end

    # Handles errors by putting a requestion on the error handler Task.
    # @param e [Exception] error to handle
    def handle_error(e)
      handler = error_handler()
      unless handler.nil?
        handler.receive(nil, Box.new([e, full_name()]))
      else
        puts "** [#{full_name()}] #{e.class}: #{e.message}"
        e.backtrace.each { |line| puts "    #{line}" }
      end
    end

  end # HasErrorHandler
end # OFlow
