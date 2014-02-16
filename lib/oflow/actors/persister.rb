require 'oj'

module OFlow
  module Actors

    # TBD
    class Persister < Actor

      attr_reader :dir
      attr_reader :key_path
      attr_reader :seq_path
      attr_reader :single_file
      attr_reader :historic

      def initialize(task, options)
        super
        @dir = options[:dir]
        if @dir.nil?
          @dir = File.join('db', task.full_name.gsub(':', '/'))
        end
        @key_path = options.fetch(:key_path, 'key')
        @seq_path = options.fetch(:seq_path, 'seq')
        if options.fetch(:cache, true)
          @cache = {}
        else
          @cache = nil
        end
        @single_file = options.fetch(:single_file, false)
        @historic = options.fetch(:historic, false)

        if Dir.exist?(@dir)
          unless @cache.nil?
            Dir.glob(File.join('**', '*.json')).each do |path|
              path = File.join(@dir, path)
              _load(path) if File.symlink?(path)
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
        raise "no key found" if key.nil?   # TBD specialized errors
        box = box.set(@seq_path, 1)
        _save(box.contents, key, 1)
      end

      def caching?()
        !@cache.nil?
      end

      def read(box)
        # Should be a Hash.
        key = box.contents[:key]
        raise "no key found" if key.nil?
        if @cache.nil? || true # TBD
          linkpath = File.join(@dir, "#{key}.json")
          rec = _load(linkpath)
        else
          rec = @cache[key]
        end
        # If not found rec will be nil, that is okay.
        rec
      end

      def update(box)
        key = box.get(@key_path)
        seq = box.get(@seq_path)
        raise "no key found" if key.nil?  # TBD specialized errors
        # TBD if seq not set then lookup cached one or from file
        seq += 1
        box = box.set(@seq_path, seq)
        _save(box.contents, key, seq)
      end

      def delete(box)
        # TBD
      end

      def query(box)
        # TBD
        # Send to provided destination or nil destination if none provided.
      end

      def clear(box)
        `rm -rf #{@dir}`
        nil
      end

      # internal use only
      def _save(rec, key, seq)
        filename = "#{key}~#{seq}.json"
        path = File.join(@dir, filename)
        linkpath = File.join(@dir, "#{key}.json")
        raise "#{path} already exists" if File.exist?(path)   # TBD specialized errors (incorrect seq num)
        Oj.to_file(path, rec, :mode => :object)
        # TBD move then delete old symlink if it exists
        begin
          File.delete(linkpath)
        rescue Exception => e
          # ignore
        end
        File.symlink(filename, linkpath)
        # TBD old prev file if not historic
        rec
      end

      def _load(path)
        Oj.load_file(path, :mode => :object)
      end

    end # Persister
  end # Actors
end # OFlow
