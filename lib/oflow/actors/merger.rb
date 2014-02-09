
module OFlow
  module Actors

    class Merger < Actor

      def initialize(task, options)
        super
        @match_key = options.fetch(:match, :tracker)
        @cnt = options.fetch(:count, 2)
        # Hash of Arrays
        @waiting = {}
      end

      def perform(op, box)
        matches = match(box)
        if matches.nil?
          waiting_add(box)
        else
          matches.each { |b| waiting_remove(b) }
          matches << box
          box = merge(matches)
          task.ship(nil, box)
        end
      end

      def box_key(box)
        key = nil
        if :tracker == @match_key
          key = box.tracker.id unless box.tracker.nil?
        elsif !@match_key.nil?
          key = box.get(@match_key)
        end
        key
      end

      def waiting_add(box)
        key = box_key(box)
        boxes = @waiting[key]
        if boxes.nil?
          @waiting[key] = [box]
        else
          boxes << box
        end
      end

      def waiting_remove(box)
        key = box_key(box)
        boxes = @waiting[key]
        # only remove the box, not a similar one or one that is ==
        boxes.delete_if { |b| box.equal?(b) }
      end

      # Should look at all the waiting boxes and determine which of those if any
      # are a match for the target. If all necessary matches are found then an
      # array of the boxes are returned, otherwise nil is returned.
      def match(target)
        key = box_key(target)
        boxes = @waiting[key]
        return nil if boxes.nil? || (boxes.size + 1) < @cnt  
        Array.new(boxes)
      end

      # Should merge the boxes and return a single box. The default is to take
      # all the box contents and place them in an Array and then merge the
      # Trackers if there are any.
      def merge(boxes)
        content = []
        tracker = nil
        boxes.each do |b|
          content << b.contents
          unless b.tracker.nil?
            if tracker.nil?
              tracker = b.tracker
            else
              tracker = tracker.merge(b.tracker)
            end
          end
        end
        Box.new(content, tracker)
      end

    end # Merger
  end # Actors
end # OFlow
