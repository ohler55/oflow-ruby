
module OFlow

  module HasName
    attr_reader :name

    def init_name(flow, name)
      @flow = flow
      @name = name.to_sym
    end

    def full_name()
      if @flow.respond_to?(:full_name)
        @flow.full_name() + ':' + @name.to_s
      else
        @name.to_s
      end
    end

  end # HasName
end # OFlow
