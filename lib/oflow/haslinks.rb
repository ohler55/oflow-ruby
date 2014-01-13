
module OFlow

  module HasLinks

    def init_links()
      @links = {}
    end

    def link(local, target, op)
      local = local.to_sym
      # TBD make sure local does not already exist
      @links[local] = Link.new(target.to_sym, op.to_sym)
    end

    def resolve_link(local)
      link = @links[local.to_sym]
      return nil if link.nil?
      link.instance_variable_set(:@target, @flow.find_task(link.target_name)) if link.target.nil?
      link
    end
    
    def resolve_all_links()
      @links.each_value { |link|
        link.instance_variable_set(:@target, @flow.find_task(link.target_name)) unless @flow.nil?
      }
    end
    
  end # HasLinks
end # OFlow
