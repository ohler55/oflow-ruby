
module OFlow

  module HasLinks

    def init_links()
      @links = {}
      @nil_link = nil
    end

    def link(local, target, op)
      op = op.to_sym unless op.nil?
      raise ConfigError.new("Link #{local} already exists.") unless _find_link(local).nil?
      if local.nil?
        @nil_link = Link.new(target.to_sym, op)
        return
      end
      local = local.to_sym
      @links[local] = Link.new(target.to_sym, op)
    end

    def resolve_link(local)
      unless @nil_link.nil?
        @nil_link.instance_variable_set(:@target, @flow.find_task(@nil_link.target_name)) if @nil_link.target.nil?
        return @nil_link
      end
      local = local.to_sym
      lnk = @links[local]
      return nil if lnk.nil?
      lnk.instance_variable_set(:@target, @flow.find_task(lnk.target_name)) if lnk.target.nil?
      lnk
    end
    
    def resolve_all_links()
      @links.each_value { |link|
        link.instance_variable_set(:@target, @flow.find_task(link.target_name)) unless @flow.nil?
      }
    end

    def _find_link(local)
      return @nil_link if local.nil?
      @links[local.to_sym]
    end
    
  end # HasLinks
end # OFlow
