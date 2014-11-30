
require 'oflow'
require 'net/http'
require 'oj'

class GemStatus < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    record = []
    @gems.each { |g|
      uri = URI("http://rubygems.org/api/v1/gems/#{g}.json")
      json = Oj.load(Net::HTTP.get(uri), mode: :compat)
      gem_rec = {
        "name" => json['name'],
        "version" => json['version'],
        "downloads" => json['downloads'],
        "version_downloads" => json['version_downloads']
      }
      record << gem_rec
    }
    task.ship(:save, ::OFlow::Box.new({ key: Time.now().to_i, rec: record }))
  end

  def set_options(options)
    ga = options[:gems]
    raise "No gems specified" if ga.nil?
    @gems = ga.split(',').map { |g| g.strip }
  end
  
end # GemStatus
