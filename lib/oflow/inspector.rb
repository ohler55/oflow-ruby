
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
               %|Displays the Task name, activity indicator, and queued count. If the terminal
supports real time updates the displays stays active until the X character is
pressed. While running options are available for sorting on name, activity,
or queue size.|)

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
      args.strip!
      recurse = false
      id = nil
      args.split(' ').each do |a|
        if '-r' == a
          recurse = true
        elsif !id.nil?
          listener.out.pl("--- Multiple Ids specified")
          return
        else
          id = a
        end
      end
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
        listener.out.pl('zzz '+task.full_name) unless Env == task
      end
    end

    def show(listener, args)
      if nil == args
        listener.out.pl("--- No Flow or Task specified")
        return
      end
      detail, id, ok = _parse_opt_id_args(args, 'v')
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
      # TBD
      # collect tasks using a walk
      # 
    end

    def tab(cmd, listener)
      super
      # TBD handle expansion of task names
    end

    def _parse_opt_id_args(args, opt)
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

  end # Inspector
end # OFlow
