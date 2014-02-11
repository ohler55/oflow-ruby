
module OFlow
  module Actors

    # TBD
    class Persister < Actor

      def initialize(task, options)
        super
        @dir = options[:dir]
        if @dir.nil?
          # TBD base on full_name
        end
        @key = options[:key_path]
        if options.fetch(:cache, true)
          @cache = {}
        else
          @cache = nil
        end
        @single_file = options.fetch(:single_file, false)
        @with_tracker = options.fetch(:with_tracker, false)
        # TBD load existing
      end

      def perform(op, box)
        case op
        when :insert, :create
          insert(box)
        when :get, :read
          read(box)
        when :update
          update(box)
        when :delete, :remove
          delete(box)
        when :query
          query(box)
        when :clear
          clear(box)
        else
          raise OpeError.new(task.full_name, op)
        end
      end

      def insert(box)
        # TBD
      end

      def read(box)
        # Should be a Hash.
        dest = box.contents[:dest]
        key = box.contents[:key]
        if @cache.nil?
          # TBD read from file
        else
          rec = @cache[key]
        end
        # Send to provided destination or nil destination if none provided.
        task.ship(dest, Box.new(rec, box.tracker))
      end

      def update(box)
        # TBD
      end

      def delete(box)
        # TBD
      end

      def query(box)
        # TBD
        # Send to provided destination or nil destination if none provided.
      end

      def clear(box)
        # TBD
      end

    end # Persister
  end # Actors
end # OFlow
