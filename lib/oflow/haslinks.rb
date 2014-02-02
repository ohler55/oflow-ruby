
module OFlow

  module HasLinks

    def init_links()
      @links = {}
    end

    def link(local, target, op)
      local = local.to_sym unless local.nil?
      op = op.to_sym unless op.nil?
      raise ConfigError.new("Link #{local} already exists.") unless @links[local].nil?
      local = local.to_sym unless local.nil?
      @links[local] = Link.new(target.to_sym, op)
    end

    def resolve_link(local)
      local = local.to_sym unless local.nil?
      lnk = @links[local] || @links[nil]
      return nil if lnk.nil?
      set_link_target(lnk) if lnk.target.nil?
      lnk
    end

    def set_link_target(lnk)
        if lnk.ingress
          task = find_task(lnk.target_name)
        else
          task = @flow.find_task(lnk.target_name)
        end
        lnk.instance_variable_set(:@target, task)
    end

    def find_link(local)
      local = local.to_sym unless local.nil?
      @links[local] || @links[nil]
    end

    def links()
      @links
    end
    
  end # HasLinks
end # OFlow
