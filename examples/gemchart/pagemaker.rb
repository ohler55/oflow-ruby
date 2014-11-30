
require 'oflow'

class PageMaker < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    task.ship(:reply, ::OFlow::Box.new({  }))
  end

  def set_options(options)
  end
  
end # PageMaker
