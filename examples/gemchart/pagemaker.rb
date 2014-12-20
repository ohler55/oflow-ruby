
require 'oflow'

class PageMaker < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    out = {
      request: {
        id: box.aget([:request, :id])
      },
      response: box.aget([:response])
    }
    results = box.aget([:results])
    if results.nil?
      json = '[]'
    else
      sets = {}
      results.each_value { |rec|
        gem = rec[:name]
        if (set = sets[gem]).nil?
          set = []
          sets[gem] = set
        end
        year,mon,day = rec[:date].split('.')
        set << [Time.new(year.to_i, mon.to_i, day.to_i).to_i()/86400, rec[:downloads], rec[:date], rec[:version]]
      }
      sets.each do |g,s|
        s.sort! { |a,b| a[0] <=> b[0] }
      end
      json = ::Oj.dump(sets, mode: :compat, indent: 2)
    end
    out_box = ::OFlow::Box.new(out)
    out_box = out_box.aset([:response, :headers, 'Content-Type'], 'text/json')
    out_box = out_box.aset([:response, :body], json)
    task.ship(:reply, out_box)
  end

  def set_options(options)
  end
  
end # PageMaker
