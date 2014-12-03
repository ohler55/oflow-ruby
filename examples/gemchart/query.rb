
require 'oflow'

class Query < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    box = box.set('dest', :result)
    box = box.set('expr', nil)
    task.ship(:query, box)
  end

  def set_options(options)
  end
  
end # Query
