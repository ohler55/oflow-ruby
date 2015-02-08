
require 'open3'
require 'thread'

module OFlow
  module Actors
    
    # 
    class ShellRepeat < Actor

      attr_reader :dir
      attr_reader :cmd
      attr_reader :timeout
      attr_reader :out

      def initialize(task, options)
        super
        @dir = options[:dir]
        @dir = '.' if @dir.nil?
        @dir = File.expand_path(@dir.strip)
        
        @cmd = options[:cmd]
        @timeout = options.fetch(:timeout, 1.0).to_f
        @timeout = 0.001 if 0.001 > @timeout
        @in = nil
        @out = nil
        @err = nil
        @pid = nil
        @outThread = nil
        @ctxs = {}
        @ctxCnt = 0
        @killLock = Mutex.new
      end

      def perform(op, box)
        if :kill == op
          status = kill()
          task.ship(:killed, Box.new(status, box.tracker))
          return
        end
        if @pid.nil?
          @in, @out, @err, wt = Open3.popen3(@cmd, chdir: @dir)
          @pid = wt[:pid]
          @outThread = Thread.start(self) do |me|
            Thread.current[:name] = me.task.full_name() + "-out"
            Oj.load(me.out, mode: :compat) do |o|
              begin
                k = o["ctx"]
                raise Exception.new("missing context in #{cmd} reply") if k.nil?
                raise Exception.new("context not found in #{cmd} reply for #{k}") unless me.hasCtx?(k)
                ctx = me.clearCtx(k)
                me.task.ship(nil, Box.new(o["out"], ctx))
              rescue Exception => e
                me.task.handle_error(e)
              end
            end
            @outThread = nil
            kill()
          end
        end
        if @in.closed?
          kill()
          return
        end
        @ctxCnt += 1
        @ctxs[@ctxCnt] = box.tracker
        wrap = { "ctx" => @ctxCnt, "in" => box.contents }
        input = Oj.dump(wrap, mode: :compat, indent: 0)
        @in.write(input + "\n")
        @in.flush
      end

      def busy?()
        !@ctxs.empty?
      end

      def getCtx(ctx)
        @ctxs[ctx]
      end

      def hasCtx?(ctx)
        @ctxs.has_key?(ctx)
      end

      def clearCtx(ctx)
        @ctxs.delete(ctx)
      end

      def kill()
        status = nil
        @killLock.synchronize do
          # kill but don't wait for an exit. Leave it orphaned so a new app can be
          # started.
          status = Process.kill("HUP", @pid) unless @pid.nil?
          @in.close() unless @in.nil?
          @out.close() unless @out.nil?
          @err.close() unless @err.nil?
          Thread.kill(@outThread) unless @outThread.nil?
          @in = nil
          @out = nil
          @err = nil
          @pid = nil
          @outThread = nil
        end
        status
      end

    end # ShellRepeat
  end # Actors
end # OFlow
