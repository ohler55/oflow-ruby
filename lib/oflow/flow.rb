
module OFlow

  # The Class used to managing interactions between Tasks and sub-Flows. It can
  # be thought of as a container for Tasks where the Flow keeps track of the
  # Links between the Tasks.
  class Flow
    include HasTasks
    include HasLinks
    include HasName
    include HasErrorHandler
    include HasLog

    # Create a new Flow.
    # @param flow [Flow] Flow containing the Flow
    # @param name [name] Flow base name
    # @param options [Hash] additional options for the Flow
    def initialize(flow, name, options)
      init_name(flow, name)
      init_tasks()
      init_links()
    end

    # Add a Link from the edge of the Flow to a Task contained in the Flow.
    # @param label [Symbol|String] identifier for the Link
    # @param task_name [Symbol|String] _name base name of teh Task to link to
    # @param op [Symbol|String] operation to call when forwarding a request to the target Task
    def route(label, task_name, op)
      op = op.to_sym unless op.nil?
      label = label.to_sym unless label.nil?
      raise ConfigError.new("Link #{label} already exists.") unless find_link(label).nil?
      @links[label] = Link.new(task_name.to_sym, op, true)
    end

    # Receive a request which is redirected to a Linked target Task.
    # @param op [Symbol] identifies the link that points to the destination Task or Flow
    # @param box [Box] contents or data for the request
    def receive(op, box)
      box = box.receive(full_name, op)
      lnk = find_link(op)
      raise LinkError.new(op) if lnk.nil? || lnk.target.nil?
      lnk.target.receive(lnk.op, box)
    end

    # Returns true if the Flow has a Link identified by the op.
    # @param op [Symbol] identifies the Link in question
    def has_input(op)
      !find_link(op).nil?
    end

    # Returns a String describing the Flow.
    # @param detail [Fixnum] higher values result in more detail in the description
    # @param indent [Fixnum] the number of spaces to indent the description
    def describe(detail=0, indent=0)
      i = ' ' * indent
      lines = ["#{i}#{name} (#{self.class}) {"]
      @tasks.each_value { |t|
        lines << t.describe(detail, indent + 2)
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
