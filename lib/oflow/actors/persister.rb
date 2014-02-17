require 'oj'

module OFlow
  module Actors

    # Actor that persists records to the local file system as JSON
    # representations of the records. Records can be the whole contents of the
    # box received or a sub element of the contents. The key to the records are
    # keys provided either in the record data or outside the data but somewhere
    # else in the box received. Options for maintaining historic records and
    # sequence number locking are included. If no sequence number is provide the
    # Persister will assume there is no checking required and write anyway.
    #
    # Records are stored as JSON with the filename as the key and sequence
    # number. The format of the file name is <key>~<seq>.json. As an example, a
    # record stored with a key of 'first' and a sequence number of 3 (third time
    # saved) would be 'first~3.json.
    class Persister < Actor

      attr_reader :dir
      attr_reader :key_path
      attr_reader :seq_path
      attr_reader :data_path
      attr_reader :historic

      # Initializes the persister with options of:
      # @param [Hash] options with keys of
      #  - :dir [String] directory to store the persisted records
      #  - :key_data [String] path to record data (default: nil (all))
      #  - :key_path [String] path to key for the record (default: 'key')
      #  - :seq_path [String] path to sequence for the record (default: 'seq')
      #  - :cache [Boolean] if true, cache records in memory
      #  - :historic [Boolean] if true, do not delete previous versions
      def initialize(task, options)
        super
        @dir = options[:dir]
        if @dir.nil?
          @dir = File.join('db', task.full_name.gsub(':', '/'))
        end
        @key_path = options.fetch(:key_path, 'key')
        @seq_path = options.fetch(:seq_path, 'seq')
        @data_path = options.fetch(:data_path, nil) # nil means all contents
        if options.fetch(:cache, true)
          # key is record key, value is [seq, rec]
          @cache = {}
        else
          @cache = nil
        end
        @historic = options.fetch(:historic, false)

        if Dir.exist?(@dir)
          unless @cache.nil?
            Dir.glob(File.join('**', '*.json')).each do |path|
              path = File.join(@dir, path)
              if File.symlink?(path)
                rec = load(path)
                unless @cache.nil?
                  key, seq = key_seq_from_path(path)
                  @cache[key] = [seq, rec]
                end
              end
            end
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
        when :delete, :remove
          result = delete(box)
        when :query
          result = query(box)
        when :clear
          result = clear(box)
        else
          raise OpError.new(task.full_name, op)
        end
        task.ship(dest, Box.new(result, box.tracker))
      end

      def insert(box)
        key = box.get(@key_path)
        raise KeyError.new(:insert) if key.nil?
        box = box.set(@seq_path, 1)
        rec = box.get(@data_path)
        @cache[key] = [1, rec] unless @cache.nil?
        save(rec, key, 1)
      end

      # Returns true if the actor is caching records.
      def caching?()
        !@cache.nil?
      end

      def read(box)
        # Should be a Hash.
        key = box.contents[:key]
        raise KeyError(:read) if key.nil?
        if @cache.nil?
          linkpath = File.join(@dir, "#{key}.json")
          rec = load(linkpath)
        else
          unless (seq_rec = @cache[key]).nil?
            rec = seq_rec[1]
          end
        end
        # If not found rec will be nil, that is okay.
        rec
      end

      def update(box)
        key = box.get(@key_path)
        raise KeyError.new(:update) if key.nil?
        seq = box.get(@seq_path)
        if @cache.nil?
          if (seq_rec = @cache[key]).nil?
            raise NotFoundError.new(key)
          end
          seq = seq_rec[0] if seq.nil?
        else
          seq = 0
          has_rec = false
          Dir.glob(File.join(@dir, '**', "#{key}*.json")).each do |path|
            if File.symlink?(path)
              has_rec = true
              next
            end
            _, s = key_seq_from_path(path)
            seq = s if seq < s
          end
        end
        raise NotFoundError.new(key) unless has_rec
        raise SeqError.new(:update, key) if seq.nil? || 0 == seq

        seq += 1
        box = box.set(@seq_path, seq)
        rec = box.get(@data_path)
        @cache[key] = [seq, rec] unless @cache.nil?
        rec = save(rec, key, seq)
        delete_historic(key, seq) unless @historic
        rec
      end

      def delete(box)
        key = box.get(@key_path)
        @cache.delete(key) unless @cache.nil?
        linkpath = File.join(@dir, "#{key}.json")
        File.delete(linkpath)
        delete_historic(key, nil) unless @historic
        nil
      end

      def query(box)
        recs = {}
        expr = box.get('expr')
        if expr.nil?
          if @cache.nil?
            Dir.glob(File.join(@dir, '**/*.json')).each do |path|
              recs[File.basename(path)[0..-6]] = load(path) if File.symlink?(path)
            end
          else
            @cache.each do |key,seq_rec|
              recs[key] = seq_rec[1]
            end
          end
        elsif expr.is_a?(Proc)
          if @cache.nil?
            Dir.glob(File.join(@dir, '**/*.json')).each do |path|
              next unless File.symlink?(path)
              rec = load(path)
              key, seq = key_seq_from_path(path)
              recs[key] = rec if expr.call(rec, key, seq)
            end
          else
            @cache.each do |key,seq_rec|
              rec = seq_rec[1]
              recs[key] = rec if expr.call(rec, key, seq_rec[0])
            end
          end
        else
          # TBD add support for string safe expressions in the future
          raise Exception.new("expr can only be a Proc, not a #{expr.class}")
        end
        recs
      end

      def clear(box)
        @cache = {} unless @cache.nil?
        `rm -rf #{@dir}`
        # remake the dir in preparation for future inserts
        `mkdir -p #{@dir}`
        nil
      end

      # internal use only
      def save(rec, key, seq)
        filename = "#{key}~#{seq}.json"
        path = File.join(@dir, filename)
        linkpath = File.join(@dir, "#{key}.json")
        raise ExistsError.new(key, seq) if File.exist?(path)
        Oj.to_file(path, rec, :mode => :object)
        begin
          File.delete(linkpath)
        rescue Exception
          # ignore
        end
        File.symlink(filename, linkpath)
        rec
      end

      def load(path)
        return nil unless File.exist?(path)
        Oj.load_file(path, :mode => :object)
      end

      def delete_historic(key, seq)
        Dir.glob(File.join(@dir, '**', "#{key}~*.json")).each do |path|
          _, s = key_seq_from_path(path)
          next if s == seq
          File.delete(path)
        end
      end

      def key_seq_from_path(path)
        path = File.readlink(path) if File.symlink?(path)
        base = File.basename(path)[0..-6] # strip off '.json'
        a = base.split('~')
        [a[0..-2].join('~'), a[-1].to_i]
      end

      class KeyError < Exception
        def initialize(op)
          super("No key found for #{op}")
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

    end # Persister
  end # Actors
end # OFlow
