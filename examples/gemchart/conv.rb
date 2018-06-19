#!/usr/bin/env ruby

require 'oj'

src_dir = File.expand_path(ARGV[0])
dest_dir = File.expand_path(ARGV[1])
cache = {}

Dir.glob(File.join(src_dir, '*.json')).each do |path|
  next if path.include?('~')
  rec = Oj.load_file(path, :mode => :object)

  tc = cache[rec[:name]]
  if tc.nil?
    tc = {}
    cache[rec[:name]] = tc
  end
  tc[rec[:date]] = rec
end

cache.each { |name,recs|
  path = File.join(dest_dir, "#{name}.json")
  Oj.to_file(path, recs, indent: 2, mode: :strict)
}




