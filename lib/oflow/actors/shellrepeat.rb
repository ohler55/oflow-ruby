
require 'open3'

module OFlow
  module Actors
    
    # 
    class ShellRepeat < Actor

      attr_reader :dir
      attr_reader :cmd
      attr_reader :timeout

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
      end

      def perform(op, box)
        input = Oj.dump(box.contents, mode: :compat, indent: 0)
        if @pid.nil?
          # TBD start app
          #  separate thread for gathering output
        end
        i, o, e, _ = Open3.popen3(@cmd, chdir: @dir)
        i.write(input)
        i.close
        giveup = Time.now + @timeout
        ra = [e, o]

        out = ''
        err = ''
        ec = false # stderr closed flag
        oc = false # stdout closed flag
        while true
          rem = giveup - Time.now
          raise Exception.new("Timed out waiting for output.") if 0.0 > rem
          rs, _, es = select(ra, nil, ra, rem)
          unless es.nil?
            es.each do |io|
              ec |= io == e
              oc |= io == o
            end
          end
          break if ec && oc
          unless rs.nil?
            rs.each do |io|
              if io == e && !ec
                if io.closed? || io.eof?
                  ec = true
                  next
                end
                err += io.read_nonblock(1000)
              elsif io == o && !oc
                if io.closed? || io.eof?
                  oc = true
                  next
                end
                out += io.read_nonblock(1000)
              end
            end
          end
          break if ec && oc
        end
        if 0 < err.length
          raise Exception.new(err)
        end
        output = Oj.load(out, mode: :compat)
        o.close
        e.close

        task.ship(nil, Box.new(output, box.tracker))
      end

    end # ShellRepeat
  end # Actors
end # OFlow
