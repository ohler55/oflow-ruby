
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
      @routes[label] = Route.new(label, task_name, op)
    end

    # Optional.
    def out(label)
      @outs << Out.new(label)
    end

    def receive(op, box)
      link = resolve_link(op)
      raise LinkError.new(op) if link.nil? || link.target.nil?
      link.target.receive(link.op, box)
    end

    def get_route(op)
      @routes[op]
    end

    def has_input(op)
      !@routes[op].nil?
    end

    def describe(indent=0)
      i = ' ' * indent
      lines = ["#{i}#{name} (#{self.class}) {"]
      @routes.each_value { |r|
        lines << "#{i}  route #{r.label} => #{r.task}:#{r.op}"
      }
      @tasks.each_value { |t|
        lines << t.describe(indent + 2)
      }
      @links.each { |local,link|
        lines << "  #{i}#{local} => #{link.target_name}:#{link.op}"
      }
      lines << i + "}"
      lines.join("\n")
    end

    def _clear()
    end

    class Route
      attr_reader :label
      attr_reader :task
      attr_reader :op

      def initialize(label, task_name, op)
        @label = label
        @task = task_name
        @op = op
      end

      def to_s()
        "Route{label: #{@label}, task: #{@task}, op: #{@op}}"
      end
      alias inspect to_s

    end # Route

    class Out
      attr_reader :label

      def initialize(label)
        @label = label
      end

      def to_s()
        "Out{#{@label}}"
      end
      alias inspect to_s

    end # Out

  end # Flow
end # OFlow
