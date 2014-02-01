
module OFlow

  class Flow
    include HasTasks
    include HasLinks
    include HasName
    include HasErrorHandler
    include HasLog

    def initialize(flow, name, options)
      init_name(flow, name)
      init_tasks()
      init_links()
      @routes = {}
      @outs = []
    end

    def route(label, task_name, op)
      op = op.to_sym unless op.nil?
      label = label.to_sym unless label.nil?
      raise ConfigError.new("Link #{label} already exists.") unless find_link(label).nil?
      @links[label] = Link.new(task_name.to_sym, op, true)
    end

    def receive(op, box)
      box = box.receive(full_name, op)
      lnk = find_link(op)
      raise LinkError.new(op) if lnk.nil? || lnk.target.nil?
      lnk.target.receive(lnk.op, box)
    end

    def has_input(op)
      !find_link(op).nil?
    end

    def describe(indent=0)
      i = ' ' * indent
      lines = ["#{i}#{name} (#{self.class}) {"]
      @tasks.each_value { |t|
        lines << t.describe(indent + 2)
      }
      @links.each { |local,link|
        if link.ingress
          lines << "  #{i}#{local} * #{link.target_name}:#{link.op}"
        else
          lines << "  #{i}#{local} => #{link.target_name}:#{link.op}"
        end
      }
      lines << i + "}"
      lines.join("\n")
    end

    def _clear()
    end

  end # Flow
end # OFlow
