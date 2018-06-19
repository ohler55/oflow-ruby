require 'oj'

module OFlow
  module Actors

    # Actor that saves records to the local file system as JSON
    # representations of the records as lines in a single file associated with
    # one of the elements of the JSON record. The message that triggers the
    # store must have a 'table' element, a 'key', and a 'rec' element.
    class Recorder < Actor

      attr_reader :dir

      # Initializes the recorder with options of:
      # @param [Hash] options with keys of
      #  - :dir [String] directory to store the persisted records
      #  - :results_path [String] path to where the results should be placed in
      #                           the request (default: nil or ship only results)
      def initialize(task, options)
        super
	@cache = {}
        @dir = options[:dir]
        if @dir.nil?
          @dir = File.join('db', task.full_name.gsub(':', '/'))
        end
        @dir = File.expand_path(@dir.strip)
        @results_path = options[:results_path]
        @results_path.strip! unless @results_path.nil?

        if Dir.exist?(@dir)
          Dir.glob(File.join(@dir, '*.json')).each do |path|
            load(path)
          end
        else
          `mkdir -p #{@dir}`
        end
      end

      def perform(op, box)
        dest = box.contents[:dest]
        result = nil
        case op
        when :insert, :create
          result = insert(box)
        when :get, :read
          result = read(box)
        when :update
          result = update(box)
        when :insert_update
          result = insert_update(box)
        when :delete, :remove
          result = delete(box)
        when :query
          result = query(box)
        when :clear
          result = clear(box)
        else
          raise OpError.new(task.full_name, op)
        end
        unless dest.nil?
          if @results_path.nil?
            box = Box.new(result, box.tracker)
          else
            box = box.set(@results_path, result)
          end
          task.ship(dest, box)
        end
      end

      def insert(box)
        table = box.get('table')
        key = box.get('key')
        rec = box.get('rec')
        raise KeyError.new(:insert) if table.nil?
        raise KeyError.new(:insert) if key.nil?

	tc = @cache[table]
	if tc.nil?
	  tc = {}
	  @cache[table] = tc
	end
        tc[key] = rec
	write(table)
      end

      alias :update :insert
      alias :insert_update :insert
      
      def read(box)
        table = box.get('table')
        key = box.get('key')
        raise KeyError.new(:read) if table.nil?
        raise KeyError.new(:read) if key.nil?

	tc = @cache[table]
	return nil if tc.nil?

	rec = tc[key]
        rec
      end

      def delete(box)
        table = box.get('table')
        key = box.get('key')
        raise KeyError.new(:read) if table.nil?
        raise KeyError.new(:read) if key.nil?

	tc = @cache[table]
	unless tc.nil?
	  tc.delete(key)
	  write(table)
	end
        nil
      end

      def query(box)
        recs = {}
        expr = box.get('expr')
        table = box.get('table')
        raise KeyError.new(:query) if table.nil?

	tc = @cache[table]
	tc.each do |key,rec|
          recs[key] = rec if (expr.nil? || expr.call(rec, key))
        end
        recs
      end

      def clear(box)
        @cache = {}
        `rm -rf #{@dir}`
        # remake the dir in preparation for future inserts
        `mkdir -p #{@dir}`
        nil
      end

      private
      
      def write(table)
        filename = "#{table}.json"
        path = File.join(@dir, filename)
        Oj.to_file(path, @cache[table], :mode => :strict)
      end

      def load(path)
        return nil unless File.exist?(path)
        tc = Oj.load_file(path, :mode => :strict, symbol_keys: true)
	name = File.basename(path)[0..-File.extname(path).size - 1]
	@cache[name] = tc
      end

      class TableError < Exception
        def initialize(table)
          super("No Table found for #{table}")
        end
      end # TableError

      class KeyError < Exception
        def initialize(key)
          super("No key found for #{key}")
        end
      end # KeyError

      class SeqError < Exception
        def initialize(op, key)
          super("No sequence number found for #{op} of #{key}")
        end
      end # SeqError

      class ExistsError < Exception
        def initialize(key, seq)
          super("#{key}:#{seq} already exists")
        end
      end # ExistsError

      class NotFoundError < Exception
        def initialize(key)
          super("#{key} not found")
        end
      end # NotFoundError

    end # Recorder
  end # Actors
end # OFlow
