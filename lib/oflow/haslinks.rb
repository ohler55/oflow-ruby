
module OFlow

  module HasLinks

    def init_links()
      @links = {}
    end

    def link(local, target, op)
      op = op.to_sym unless op.nil?
      raise ConfigError.new("Link #{local} already exists.") unless find_link(local).nil?
      local = local.to_sym unless local.nil?
      @links[local] = Link.new(target.to_sym, op)
    end

    def resolve_link(local)
      local = local.to_sym unless local.nil?
      lnk = @links[local] || @links[nil]
      return nil if lnk.nil?
      lnk.instance_variable_set(:@target, @flow.find_task(lnk.target_name)) if lnk.target.nil?
      lnk
    end
    
    def find_link(local)
      local = local.to_sym unless local.nil?
      @links[local] || @links[nil]
    end
    
  end # HasLinks
end # OFlow
