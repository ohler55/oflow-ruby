
require 'ox'

module OFlow

  class Graffle
    attr_accessor :name
    attr_accessor :line_info
    attr_accessor :task_info

    def self.load(env, filename)
      doc = Ox.load_file(filename, mode: :generic)
      g = Graffle.new(env, filename, doc)
      env.debug(g.to_s()) if Logger::Severity::DEBUG >= ::OFlow::Env.log_level
    end

    def initialize(env, filename, doc)
      @line_info = { } # key is id
      @task_info = { } # key is id
      @name = File.basename(filename, '.graffle')

      nodes = doc.locate('plist/dict')[0].nodes
      nodes = Graffle.get_key_value(nodes, 'GraphicsList')

      raise ConfigError.new("Empty flow.") if nodes.nil?
      
      nodes.each do |node|
        load_node(node)
      end

      # set label in lines
      task_info.each do |id,ti|
        next if ti.line_id.nil?
        if !(li = line_info[ti.line_id]).nil?
          li.label, li.op = ti.first_option
        end
      end
      task_info.each do |_, ti|
        if ti.name.nil? && !(n = ti.options[:flow]).nil?
          @name = n.strip
        end
      end
      env.flow(@name.to_sym) { |f|
        task_info.each_value { |ti|
          next unless ti.line_id.nil?
          next if ti.name.nil?
          c = ti.get_class()
          next if c.nil?
          f.task(ti.name, c, ti.options) { |t|
            t.bounds = ti.bounds
            t.color = ti.color
            t.shape = ti.shape
            line_info.each_value { |li|
              next unless li.tail == ti.id
              target_info = task_info[li.head]
              if target_info.nil?
                flow_name, task_name, op = li.op.split('/')
                t.link(li.label, task_name, op, flow_name)
              else
                t.link(li.label, target_info.name, li.op)
              end
            }
          }
        }
      }
    end

    def load_node(node)
      nodes = node.nodes
      case Graffle.get_key_value(nodes, 'Class')
      when 'LineGraphic'
        line = LineInfo.new(nodes)
        @line_info[line.id] = line
      when 'ShapedGraphic'
        task = TaskInfo.new(nodes)
        @task_info[task.id] = task unless task.nil?
      end
    end

    def to_s()
      s = "Graffle{\n  name: #{@name}\n  tasks{\n"
      task_info.each { |_,ti| s += "    #{ti}\n" }
      s += "  }\n  lines{\n"
      line_info.each { |_,li| s += "    #{li}\n" }
      s += "  }\n}\n"
      s
    end

    def self.get_key_value(nodes, key)
      return if nodes.nil?
      nodes.each_with_index do |node,i|
        next unless 'key' == node.name && key == node.text
        n = nodes[i + 1]
        if 'dict' == n.name || 'array' == n.name
          return n.nodes
        else
          return n.text
        end
      end
      nil
    end

    def self.get_text(nodes)
      return nil if nodes.nil?
      strip_rtf(get_key_value(nodes, 'Text'))
    end

    def self.strip_rtf(rtf)
      return rtf unless rtf.start_with?('{\rtf')
      depth = 0
      txt = ''
      ctrl = nil
      str = nil
      rtf.each_char do |c|
        case c
        when ' '
          if !str.nil?
            str << ' ' unless 1 < depth
          elsif !ctrl.nil?
            txt << rtf_ctrl_char(ctrl) unless 1 < depth
            ctrl = nil
            str = ''
          else
            str = ''
          end
        when "\n", "\r"
          if !str.nil? # should not happen but...
            str << "\n" unless 1 < depth
          elsif !ctrl.nil?
            txt << rtf_ctrl_char(ctrl) unless 1 < depth
            ctrl = nil
          end
        when '\\'
          if !str.nil?
            txt << str unless 1 < depth
            str = nil
          elsif !ctrl.nil?
            txt << rtf_ctrl_char(ctrl) unless 1 < depth
          end
          ctrl = ''
        when '{'
          if !ctrl.nil?
            txt << rtf_ctrl_char(ctrl) unless 1 < depth
            ctrl = nil
          end
          depth += 1
        when '}'
          if !ctrl.nil?
            txt << rtf_ctrl_char(ctrl) unless 1 < depth
            ctrl = nil
          end
          depth -= 1
        else
          if !ctrl.nil?
            ctrl << c
          elsif 1 < depth
            # ignore
          else
            str = '' if str.nil?
            str << c
          end
        end
      end
      txt << str unless str.nil?
      txt
    end

    def self.rtf_ctrl_char(ctrl)
      c = ''
      case ctrl
      when '', 'line'
        c = "\n"
      when 'tab'
        c = "\t"
      else
        if "'" == ctrl[0]
          c = ctrl[1..3].hex().chr
        end
      end
      c
    end

    class Element
      attr_accessor :id

      def initialize(nodes)
        return if nodes.nil?
        @id = Graffle.get_key_value(nodes, 'ID')
      end
      
    end # Element

    class LineInfo < Element
      attr_accessor :tail
      attr_accessor :head
      attr_accessor :label
      attr_accessor :op

      def initialize(nodes)
        super
        @tail = Graffle.get_key_value(Graffle.get_key_value(nodes, 'Tail'), 'ID')
        @head = Graffle.get_key_value(Graffle.get_key_value(nodes, 'Head'), 'ID')
      end
      
      def to_s()
        "LineInfo{id:#{@id}, tail:#{@tail}, head:#{@head}, label: #{label}:#{op}}"
      end
    end # LineInfo

    class TaskInfo < Element
      attr_accessor :line_id
      attr_accessor :name
      attr_accessor :options
      attr_accessor :color
      attr_accessor :shape
      attr_accessor :bounds
      
      def initialize(nodes)
        super
        if (ln = Graffle.get_key_value(nodes, 'Line')).nil?
          @line_id = nil
        else
          @line_id = Graffle.get_key_value(ln, 'ID')
        end
        @shape = Graffle.get_key_value(nodes, 'Shape')
        color_node = Graffle.get_key_value(Graffle.get_key_value(Graffle.get_key_value(nodes, 'Style'), 'fill'), 'Color')
        if color_node.nil?
          @color = nil
        else
          @color = [Graffle.get_key_value(color_node, 'r').to_f,
                    Graffle.get_key_value(color_node, 'g').to_f,
                    Graffle.get_key_value(color_node, 'b').to_f]
        end
        unless (@bounds = Graffle.get_key_value(nodes, 'Bounds')).nil?
          @bounds = @bounds.delete('{}').split(',')
          @bounds.map! { |s| s.to_i }
        end
        @options = { }
        text = Graffle.get_text(Graffle.get_key_value(nodes, 'Text'))
        unless text.nil?
          text.split("\n").each do |line|
            pair = line.split(':', 2)
            if 1 == pair.length
              @name = pair[0]
            else
              k = pair[0]
              if 0 == k.length
                k = nil
              else
                k = k.to_sym
              end
              @options[k] = pair[1]
            end
          end
        end
      end

      def first_option()
        target = nil
        op = nil
        if name.nil?
          options.each { |k,v| target, op = k, v; break }
        else
          target = name
        end
        [target, op]
      end

      def get_class()
        return nil if options.nil?
        return nil if (s = options[:class]).nil?
        s.strip!
        c = nil
        begin
          # TBD search all modules and classes for a match that is also an Actor

          # Assume the environment is safe since it is being used to create
          # processes from user provided code anyway.
          c = Object.class_eval(s)
        rescue Exception
          c = ::OFlow::Actors.module_eval(s)
        end
        c
      end

      def to_s()
        "TaskInfo{id:#{@id}, line_id:#{line_id}, name: #{name}, options: #{options}, bounds: #{@bounds}, shape: #{@shape}, color: #{@color}}"
      end

    end # TaskInfo

  end # Graffle
end # OFlow
