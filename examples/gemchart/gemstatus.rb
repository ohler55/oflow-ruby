
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
      uri = URI("https://rubygems.org/api/v1/gems/#{g}.json")
      begin
        info = get_gem_info(uri)
        if info.nil?
          # raise to build the backtrace
          raise Exception.new("#{uri} failed to load JSON.")
        end
      rescue Exception => e
        task.handle_error(e)
        next
      end
      rec = {
        date: "%04d.%02d.%02d" % [now.year, now.month, now.day],
        julian: now.mjd,
        name: info['name'],
        version: info['version'],
        downloads: info['downloads'],
        version_downloads: info['version_downloads']
      }
      task.ship(:save, ::OFlow::Box.new({ table: rec[:name], key: rec[:date], rec: rec }))
    }
  end

  def get_gem_info(uri)
    err = nil
    [1, 4, 16, 256].each do |duration|
      begin
        response = Net::HTTP.get(uri)
        return Oj.load(response, mode: :compat)
      rescue Exception => e
        err = e
        sleep(duration)
      end
    end
    raise err
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
    uri = URI("https://rubygems.org/api/v1/versions/#{g}.json")
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
      r[:downloads] = dcnt
      dcnt += r[:version_downloads]
      task.ship(:save, ::OFlow::Box.new({ table: r[:name], key: r[:date], rec: r }))
    }
  end

end # GemStatus
