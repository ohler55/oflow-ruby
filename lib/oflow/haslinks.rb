
module OFlow

  # Adds support for Links. Used by Flow and Env.
  module HasLinks

    # Sets up the links attribute.
    def init_links()
      @links = {}
    end

    # Creates a Link identified by the label that has a target Task or Flow and
    # operation.
    # @param label [Symbol|String] identifer of the Link
    # @param target [Symbol|String] identifer of the target Task
    # @param op [Symbol|String] operation to perform on the target Task
    def link(label, target, op)
      label = label.to_sym unless label.nil?
      op = op.to_sym unless op.nil?
      raise ConfigError.new("Link #{label} already exists.") unless @links[label].nil?
      label = label.to_sym unless label.nil?
      @links[label] = Link.new(target.to_sym, op)
    end

    # Attempts to find and resolve the Link identified by the label. Resolving a
    # Link uses the target identifier to find the target Task and save that in
    # the Link.
    # @param label [Symbol|String] identifer of the Link
    # @return [Link] returns the Link for the label
    def resolve_link(label)
      label = label.to_sym unless label.nil?
      lnk = @links[label] || @links[nil]
      return nil if lnk.nil?
      set_link_target(lnk) if lnk.target.nil?
      lnk
    end

    # Sets the target Task for a Link.
    # @param lnk [Link] Link to find the target Task for.
    def set_link_target(lnk)
        if lnk.ingress
          task = find_task(lnk.target_name)
        else
          task = @flow.find_task(lnk.target_name)
        end
        lnk.instance_variable_set(:@target, task)
    end

    # Attempts to find the Link identified by the label.
    # @param label [Symbol|String] identifer of the Link
    # @return [Link] returns the Link for the label
    def find_link(label)
      label = label.to_sym unless label.nil?
      @links[label] || @links[nil]
    end

    # Returns the Links.
    # @return [Hash] Hash of Links with the keys as Symbols that are the labels of the Links.
    def links()
      @links
    end

    def has_links?()
      !@links.nil? && !@links.empty?
    end

  end # HasLinks
end # OFlow
