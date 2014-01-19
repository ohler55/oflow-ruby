
module OFlow

  module HasErrorHandler

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
