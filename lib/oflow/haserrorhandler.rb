
module OFlow

  # Provides functionality to find an error handler Task which is how error are
  # handled in the system. Each Flow or Task can have a different error
  # handler. If a Flow does not have an error handler the error bubbles up to
  # the next Flow until an error handler is found.
  module HasErrorHandler

    # Sets avaliable for handling errors.
    # @param t [Task|nil] Task for handling error or nil to unset
    def error_handler=(t)
      @error_handler = t
    end

    # Handles errors by putting a requestion on the error handler Task.
    # @param e [Exception] error to handle
    def handle_error(e)
      handler = error_handler()
      if handler.nil?
        puts "** [#{full_name()}] #{e.class}: #{e.message}"
        e.backtrace.each { |line| puts "    #{line}" }
      else
        handler.receive(nil, Box.new([e, full_name()]))
      end
    end

  end # HasErrorHandler
end # OFlow
