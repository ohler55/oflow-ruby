
require 'oterm'

module OFlow

  class Inspector < ::OTerm::Executor
    attr_reader :running

    def initialize(port=6060)
      super()
      @running = true
      
      register('busy', self, :busy, 'returns the busy state of the system.', nil)
      register('list', self, :list, '[-r] [<id>] lists Flows and Tasks.',
               %|Shows a list of Flow and Task full names that fall under the id if one is
provided, otherwise the top leve is assumed. If the -r option is specified then
the names of all the Flows and Tasks under the named item are displayed.|)
      register('show', self, :show, '[-v] <id> displays a description of a Flow or Task.',
               %|Shows a description of the identified Flow or Task. If the -v option is
specified then a detailed description of the Tasks is displayed which included
the number of requests queued and the status of the Task. More -v arguments
will give increasing more detail.|)
      register('start', self, :start, '[<task id>] start or restart a Task.', nil)
      register('step', self, :step, '[<task id>] step once.',
               %|Step once for the Task specfified or once for some Task that is
waiting if no Task is identified.|)
      register('stop', self, :stop, '[<task id>] stops a Task.', nil)
      register('verbosity', self, :verbosity, '[<level>] show or set the verbosity or log level.', nil)
      register('watch', self, :watch, '[<task id> displays status of Tasks.',
               %|Displays the Task name, activity indicator, queued count, and number of
requests processed. If the terminal supports real time updates the displays
stays active until the X character is pressed. While running options are
available for sorting on name, activity, or queue size.|)

      # register('debug', self, :debug, 'toggles debug mode.', nil)

      @server = ::OTerm::Server.new(self, port, false)
    end

    def join()
      @server.join()
    end

    def shutdown(listener, args)
      super
      @running = false
      Env.shutdown()
    end

    def greeting()
      "Welcome to the Operations Flow Inspector."
    end

    def debug(listener, args)
      @server.debug = !@server.debug
    end

    def busy(listener, args)
      if Env.busy?()
        listener.out.pl("One or more Tasks is busy.")
      else
        listener.out.pl("All Tasks are idle.")
      end
    end

    def flows(listener, args)
      Env.each_task() do |t|
        listener.out.pl(t.full_name)
      end
    end

    def list(listener, args)
      if nil == args
        Env.each_task() do |task|
          listener.out.pl(task.full_name)
        end
        return
      end
      recurse, id, ok = _parse_opt_id_args(args, 'r', listener)
      return unless ok
      if id.nil?
        flow = Env
      else
        flow = Env.locate(id)
      end
      if flow.nil?
        listener.out.pl("--- No Flow or Task found for #{id}")
        return
      end
      _walk(flow, recurse, listener) do |task|
        listener.out.pl(task.full_name) unless Env == task
      end
    end

    def show(listener, args)
      if nil == args
        listener.out.pl("--- No Flow or Task specified")
        return
      end
      detail, id, ok = _parse_opt_id_args(args, 'v', listener)
      return unless ok

      task = Env.locate(id)
      if task.nil?
        listener.out.pl("--- Failed to find '#{id}'")
        return
      end
      listener.out.pl(task.describe(detail))
    end

    def start(listener, args)
      if nil == args || 0 == args.size()
        Env.start()
        listener.out.pl("All Tasks restarted")
      else
        args.strip!
        task = Env.locate(args)
        if task.nil?
          listener.out.pl("--- Failed to find '#{args}'")
        else
          task.start()
          listener.out.pl("#{task.full_name} restarted")
        end
      end
    end

    def step(listener, args)
      lg = Env.log()
      stop_after = false
      if !lg.nil? && Task::STOPPED == lg.state
        lg.start()
        stop_after = true
      end

      if nil == args || 0 == args.size()
        task = Env
      else
        args.strip!
        task = Env.locate(args)
      end
      if task.nil?
        listener.out.pl("--- Failed to find '#{args}'")
      else
        task = task.step()
        if task.nil?
          listener.out.pl("--- No tasks in '#{args}' are stopped or have have queued requests")
        else
          listener.out.pl("#{task.full_name} stepped")
        end
      end
      lg.stop() if stop_after
    end

    def stop(listener, args)
      if nil == args || 0 == args.size()
        Env.stop()
        listener.out.pl("All Tasks stopped(paused)")
      else
        args.strip!
        task = Env.locate(args)
        if task.nil?
          listener.out.pl("--- Failed to find '#{args}'")
        else
          task.stop()
          listener.out.pl("#{task.full_name} stopped(paused)")
        end
      end
    end

    def verbosity(listener, args)
      lg = Env.log
      if lg.nil?
        listener.out.pl("--- No logger")
        return
      end
      lga = lg.actor
      if nil != args && 0 < args.size()
        args.strip!
        lg.receive(:severity, Box.new(args))
        listener.out.pl("verbosity change pending")
      elsif lga.respond_to?(:severity)
        listener.out.pl("verbosity: #{lga.severity()}")
      else
        listener.out.pl("--- Logger does support requests for verbosity level")
      end
    end

    def watch(listener, args)
      tasks = []
      if args.nil? || 0 == args.size()
        Env.walk_tasks() { |t| tasks << t }
      else
        args.strip!
        task = Env.locate(args)
        if task.nil?
          listener.out.pl("--- Failed to find '#{args}'")
          return
        elsif task.kind_of?(HasTasks)
          task.walk_tasks() { |t| tasks << t }
        else
          tasks << task
        end
      end
      if listener.out.is_vt100?
        _dynamic_watch(listener, tasks)
      else
        max_len = 10
        tasks.each do |t|
          len = t.full_name.size
          max_len = len if max_len < len
        end
        listener.out.pl("  %#{max_len}s  %-11s  %5s  %9s" % ['Task Name', 'Q-cnt/max', 'busy?', 'processed'])
        tasks.each do |t|
          listener.out.pl("  %#{max_len}s  %5d/%-5d  %5s  %9d" % [t.full_name, t.queue_count(), t.max_queue_count().to_i, t.busy?(), t.proc_count()])
        end
      end
    end

    # sort by values
    BY_NAME = 'name'
    BY_ACTIVITY = 'activity'
    BY_QUEUE = 'queued'
    BY_COUNT = 'count'
    BY_STATE = 'state'

    def _dynamic_watch(listener, tasks)
      o = listener.out
      sort_by = BY_NAME
      rev = false
      delay = 0.4
      tasks.map! { |t| TaskStat.new(t) }
      lines = tasks.size + 3
      h, w = o.screen_size()
      lines = h - 1 if lines > h - 1
      o.clear_screen()
      done = false
      until done
        tasks.each { |ts| ts.refresh() }
        max = 6
        max_n = 1
        tasks.each do |ts|
          max = ts.name.size if max < ts.name.size
          max_n = ts.count.size if max_n < ts.count.size
        end
        # 5 for space between after, 3 for state, max_n for number
        max_q = w - max - 8 - max_n

        case sort_by
        when BY_NAME
          if rev
            tasks.sort! { |a,b| b.name <=> a.name }
          else
            tasks.sort! { |a,b| a.name <=> b.name }
          end
        when BY_ACTIVITY
          if rev
            tasks.sort! { |a,b| a.activity <=> b.activity }
          else
            tasks.sort! { |a,b| b.activity <=> a.activity }
          end
        when BY_QUEUE
          if rev
            tasks.sort! { |a,b| a.queued <=> b.queued }
          else
            tasks.sort! { |a,b| b.queued <=> a.queued }
          end
        when BY_COUNT
          if rev
            tasks.sort! { |a,b| a.proc_cnt <=> b.proc_cnt }
          else
            tasks.sort! { |a,b| b.proc_cnt <=> a.proc_cnt }
          end
        when BY_STATE
          if rev
            tasks.sort! { |a,b| a.state <=> b.state }
          else
            tasks.sort! { |a,b| b.state <=> a.state }
          end
        end
        o.set_cursor(1, 1)
        o.bold()
        o.underline()
        o.p("%1$*2$s ? %3$*4$s @ Queued %5$*6$s" % ['#', -max_n, 'Task', -max, ' ', max_q])
        o.attrs_off()
        i = 2
        tasks[0..lines].each do |ts|
          o.set_cursor(i, 1)
          o.p("%1$*2$s %5$c %3$*4$s " % [ts.count, max_n, ts.name, -max, ts.state])
          o.set_cursor(i, max + max_n + 5)
          case ts.activity
          when 0
            o.p(' ')
          when 1
            o.p('.')
          when 2, 3
            o.p('o')
          else
            o.p('O')
          end
          o.p(' ')
          qlen = ts.queued
          qlen = max_q if max_q < qlen
          if 0 < qlen
            o.reverse()
            o.p("%1$*2$d" % [ts.queued, -qlen])
            o.attrs_off()
          end
          o.clear_to_end()
          i += 1
        end
        o.bold()
        o.set_cursor(i, 1)
        if rev
          o.p("E) exit  R) ")
          o.reverse()
          o.p("reverse")
          o.attrs_off()
          o.bold()
          o.p("  +) faster  -) slower [%0.1f]" % [delay])
        else
          o.p("E) exit  R) reverse  +) faster  -) slower [%0.1f]" % [delay])
        end
        i += 1
        o.set_cursor(i, 1)
        o.p('sort by')
        { '#' => BY_COUNT, '?' => BY_STATE, 'N' => BY_NAME, 'A' => BY_ACTIVITY, 'Q' => BY_QUEUE }.each do |c,by|
          if by == sort_by
            o.p("  #{c}) ")
            o.reverse()
            o.p(by)
            o.attrs_off()
            o.bold()
          else
            o.p("  #{c}) #{by}")
          end
        end
        o.attrs_off()

        c = o.recv_wait(1, delay, /./)
        unless c.nil?
          case c[0]
          when 'e', 'E'
            done = true
          when 'n', 'N'
            sort_by = BY_NAME
            rev = false
          when 'a', 'A'
            sort_by = BY_ACTIVITY
            rev = false
          when 'q', 'Q'
            sort_by = BY_QUEUE
            rev = false
          when '#', 'c', 'C'
            sort_by = BY_COUNT
            rev = false
          when '?', 's', 'S'
            sort_by = BY_STATE
            rev = false
          when 'r', 'R'
            rev = !rev
          when '+'
            delay /= 2.0 unless delay <= 0.1
          when '-'
            delay *= 2.0 unless 3.0 <= delay
          end
        end
      end
      o.pl()
    end

    def tab(cmd, listener)
      start = cmd.index(' ')
      if start.nil?
        super
        return
      end
      op = cmd[0...start]
      start = cmd.rindex(' ')
      pre = cmd[0...start]
      last = cmd[start + 1..-1]

      return if '-' == last[0]

      # Tab completion is different depending on the command.
      names = []
      case op.downcase()
      when 'verbosity'
        names = ['fatal', 'error', 'warn', 'info', 'debug'].select { |s| s.start_with?(last.downcase()) }
      else # expect id or options
        with_colon = ':' == last[0]
        Env.walk_tasks(false) do |t|
          fn = t.full_name
          fn = fn[1..-1] unless with_colon
          names << fn if fn.start_with?(last)
        end
      end
      
      return if 0 == names.size
      if 1 == names.size
        listener.move_col(1000)
        listener.insert(names[0][last.size..-1])
        listener.out.prompt()
        listener.out.p(listener.buf)
      else
        listener.out.pl()
        names.each do |name|
          listener.out.pl("#{pre} #{name}")
        end
        best = best_completion(last, names)
        if best == last
          listener.update_cmd(0)
        else
          listener.move_col(1000)
          listener.insert(best[last.size..-1])
          listener.out.prompt()
          listener.out.p(listener.buf)
        end
      end
    end

    def _parse_opt_id_args(args, opt, listener)
      opt_cnt = 0
      id = nil
      args.strip!
      args.split(' ').each do |a|
        if '-' == a[0]
          a[1..-1].each_char do |c|
            if c == opt
              opt_cnt += 1
            else
              listener.out.pl("--- -#{c} is not a valid option")
              return [0, nil, false]
            end
          end
        elsif !id.nil?
          listener.out.pl("--- Multiple Ids specified")
          return [0, nil, false]
        else
          id = a
        end
      end
      [opt_cnt, id, true]
    end

    def _walk(flow, recurse, listener, &block)
      if flow.respond_to?(:each_task)
        if recurse
          block.yield(flow)
          flow.each_task() do |task|
            _walk(task, true, listener, &block)
          end
        else
          flow.each_task() do |task|
            block.yield(task)
          end
        end
      else
        block.yield(flow)
      end
    end

    class TaskStat
      attr_reader :task
      attr_reader :queued
      attr_reader :activity
      attr_reader :name
      attr_reader :proc_cnt
      attr_reader :count
      attr_reader :state

      STATE_MAP = {
        Task::STARTING => '^',
        Task::STOPPED => '*',
        Task::RUNNING => ' ',
        Task::CLOSING => 'X',
        Task::BLOCKED => '-',
        Task::STEP => 's',
      }
      def initialize(t)
        @task = t
        @proc_cnt = t.proc_count()
        @activity = 0
        @queued = t.queue_count()
        @name = t.full_name
        @count = @proc_cnt.to_s
        @state = STATE_MAP.fetch(t.state, '?')
      end

      def refresh()
        cnt = @task.proc_count()
        @activity = cnt - @proc_cnt
        @proc_cnt = cnt
        @queued = @task.queue_count()
        @count = cnt.to_s
        @state = STATE_MAP.fetch(@task.state, '?')
      end

    end # TaskStat

  end # Inspector
end # OFlow
