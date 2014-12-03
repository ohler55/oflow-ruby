
require 'date'
require 'oflow'
require 'net/http'
require 'oj'

class GemStatus < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    @preload = false
    super
  end

  def perform(op, box)
    preload() if @preload
    now = DateTime.now
    @gems.each { |g|
      uri = URI("http://rubygems.org/api/v1/gems/#{g}.json")
      json = Oj.load(Net::HTTP.get(uri), mode: :compat)
      key = "%s-%04d.%02d.%02d" % [g, now.year, now.month, now.day]
      rec = {
        date: "%04d.%02d.%02d" % [now.year, now.month, now.day],
        julian: now.mjd,
        name: json['name'],
        version: json['version'],
        downloads: json['downloads'],
        version_downloads: json['version_downloads']
      }
      task.ship(:save, ::OFlow::Box.new({ key: key, rec: rec }))
    }
  end

  def set_options(options)
    ga = options[:gems]
    raise "No gems specified" if ga.nil?
    @gems = ga.split(',').map { |g| g.strip }
  end

  def set_option(key, value)
    case key.to_sym()
    when :preload
      @preload = ('true' == value)
    else
      super
    end
  end
  
  def preload()
    @gems.each { |g|
      preload_gem(g)
    }
    @preload = false
  end

  def preload_gem(g)
    uri = URI("http://rubygems.org/api/v1/versions/#{g}.json")
    json = Oj.load(Net::HTTP.get(uri), mode: :compat)
    recs = []
    json.each { |r|
      t = DateTime.parse(r['built_at'])
      date = "%04d.%02d.%02d" % [t.year, t.month, t.day]
      recs << {
        date: date,
        julian: t.mjd,
        name: g,
        version: r['number'],
        downloads: 0,
        version_downloads: r['downloads_count'].to_i
      }
    }
    recs.sort_by! { |r| r[:julian] }
    dcnt = 0
    recs.each { |r|
      dcnt += r[:version_downloads]
      r[:downloads] = dcnt
      key = "%s-%s" % [r[:name], r[:date]]
      task.ship(:save, ::OFlow::Box.new({ key: key, rec: r }))
    }
  end

end # GemStatus
