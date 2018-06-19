
require 'oflow'

class Switch < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    path = box.get('request:path')
    if path.nil? || '/' == path || '' == path
      path = '/home.html'
      box = box.aset([:request, :path], path)
    end
    if path.end_with?('.json')
      box = box.set('dest', :result)
      gem = path[1...-5]
      box = box.set('expr', nil)
      box = box.set('table', gem)
      task.ship(:query, box)
    else
      task.ship(:static, box)
    end
  end

  def set_options(options)
  end
  
end # Switch
