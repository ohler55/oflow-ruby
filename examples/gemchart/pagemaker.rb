
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
    out_box = ::OFlow::Box.new(out)
    out_box = out_box.aset([:response, :body], "Not yet")
    task.ship(:reply, out_box)
  end

  def set_options(options)
  end
  
end # PageMaker
