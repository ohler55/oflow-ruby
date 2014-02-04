
module OFlow

  # Adds support for a name attribute and the ability to form full name for a
  # named item.
  module HasName
    # The name.
    attr_reader :name

    # The containing Flow is used to support the full_name() method otherwise it
    # just sets the name.
    # @param flow [Flow|Env] containing Flow
    # @param name [Symbol|String] base name
    def init_name(flow, name)
      @flow = flow
      @name = name.to_sym
    end

    # Similar to a full file path. The full_name described the containment of
    # the named item.
    # @return [String] full name of item
    def full_name()
      if @flow.respond_to?(:full_name)
        @flow.full_name() + ':' + @name.to_s
      else
        @name.to_s
      end
    end

  end # HasName
end # OFlow
