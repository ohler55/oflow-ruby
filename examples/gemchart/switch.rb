
require 'oflow'

class Switch < ::OFlow::Actor
  
  def initialize(task, options={})
    set_options(options)
    super
  end

  def perform(op, box)
    path = box.get('request:path')
    if path.end_with?('.json')
      # TBD narrow down search
      box = box.set('dest', :result)
      box = box.set('expr', nil)
      task.ship(:query, box)
    else
      box = box.aset([:request, :path], '/home.html') if path.nil? || '/' == path || '' == path
      task.ship(:static, box)
    end
  end

  def set_options(options)
  end
  
end # Switch
