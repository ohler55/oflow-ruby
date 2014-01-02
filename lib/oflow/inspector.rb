
require 'oterm'

module OFlow

  class Inspector < ::OTerm::Executor

    def initialize(port=6060)
      super()

      @server = ::OTerm::Server.new(self, port, false)
    end

    def join()
      @server.join()
    end

    def shutdown(listener, args)
      super
    end

    def greeting()
      "Welcome to the Operations Flow Inspector."
    end

    def tab(cmd, listener)
      super
    end

  end # Inspector
end # OFlow
