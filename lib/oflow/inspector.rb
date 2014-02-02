
require 'oterm'

module OFlow

  class Inspector < ::OTerm::Executor

    def initialize(port=6060)
      super()
      
      register('busy', self, :busy, 'Returns the busy state of the system.', nil)

      # TBD register functions

      @server = ::OTerm::Server.new(self, port, false)
    end

    def join()
      @server.join()
    end

    def shutdown(listener, args)
      super
      Env.shutdown()
    end

    def greeting()
      "Welcome to the Operations Flow Inspector."
    end

    def busy(listener, args)
      if Env.busy?()
        listener.out.pl("One or more Tasks is busy.")
      else
        listener.out.pl("All Tasks are idle.")
      end
    end

    def tab(cmd, listener)
      super
    end

  end # Inspector
end # OFlow
