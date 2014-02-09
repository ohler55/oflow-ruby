
module OFlow
  module Actors

    # Redirects operations to one Task out of all the linked tasks. It uses the
    # Task.backed_up() method to determine which task is the least busy. It also
    # attempts to distribute requests somewhat evenly if Tasks are equally as
    # busy.
    class Balancer < Actor

      def initialize(task, options)
        super
        @cnt = 0
        @called = {}
      end

      def perform(op, box)
        best = nil
        order = nil
        bbu = nil
        @task.links().each do |dest,lnk|
          t = lnk.target
          next if t.nil?
          bu = t.backed_up()
          if bbu.nil? || bu < bbu || (bbu == bu && @called.fetch(dest, 0) < order)
            best = dest
            bbu = bu
            order = @called.fetch(dest, 0)
          end
        end
        @cnt += 1
        @called[best] = @cnt
        task.ship(best, box)
      end

    end # Balancer
  end # Actors
end # OFlow
