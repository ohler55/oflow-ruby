
require 'oflow'

class Query < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    task.ship(:query, ::OFlow::Box.new({ dest: :result, expr: nil }))
  end

  def set_options(options)
  end
  
end # Query
