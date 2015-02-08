
require 'open3'

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
      end

      def clearCtx(ctx)
        @ctxs.delete(ctx)
      end

      def perform(op, box)
        # TBD if op is :kill then kill pid and ship exit status
        if @pid.nil?
          @in, @out, @err, wt = Open3.popen3(@cmd, chdir: @dir)
          @pid = wt[:pid]
          @outThread = Thread.start(self) do |me|
            #Thread.current[:name] = me.full_name() + ":out"
            Oj.load(me.out, mode: :compat) do |o|
              begin
                puts "*** output: #{o}"
                # TBD make sure ctx is present in the output and also in the ctxs, decide what the right actions is if not
                me.clearCtx(o["ctx"])
                # TBD get ctx from output
                me.task.ship(nil, Box.new(o))
                #task.ship(nil, Box.new(o, box.tracker)) # TBD get tracker from some saved unique id
              rescue Exception => e
                puts "*** #{e.class}: #{e.message}"
              end
            end
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

      def kill()
        # mutex protect?
        # TBD kill pid if not dead
        @in = nil
        @out = nil
        @err = nil
        @pid = nil
        @outThread = nil
      end

    end # ShellRepeat
  end # Actors
end # OFlow
