#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

require 'collector'

class Dummy < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.ship(op, box)
  end

end # Dummy

class Miss < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    case op
    when :one
      task.ship(:one, box)
    when :two
      task.ship(:two, box)
    end
  end

  def inputs()
    [ ::OFlow::Actor::Spec.new(:fixnum, Fixnum),
      ::OFlow::Actor::Spec.new(:float, nil) ]
  end

  def outputs()
    [ ::OFlow::Actor::Spec.new(:fixnum, Fixnum),
      ::OFlow::Actor::Spec.new(:float, Float) ]
  end

end # Miss

class FlowCfgErrTest < ::Test::Unit::TestCase

  def test_flow_link_unresolved
    begin
      ::OFlow::Env.flow('unresolved', :opt1 => 1) { |f|
        f.task(:one, Dummy) { |t|
          t.link(:two, :two, nil)
        }
        f.task(:three, Dummy) { |t|
          t.link(:second, :two, nil)
        }
      }
      assert(false, "expected a ValidateError")
    rescue ::OFlow::ValidateError => ve
      assert_equal([":unresolved:one: Failed to find task 'two'.",
                    ":unresolved:three: Failed to find task 'two'."], ve.problems.map { |p| p.to_s })
    end
    ::OFlow::Env.clear()
  end

  def test_flow_link_missing
    begin
      ::OFlow::Env.flow('miss-me') { |f|
        f.task(:sort, Miss) { |t|
          t.link(:fixnum, :fix, nil)
        }
        f.task(:fix, Dummy) { |t|
          t.link(:repeat, :sort, :float)
          t.link(:wrong, :sort, :complex)
        }
      }
      assert(false, "expected a ValidateError")
    rescue ::OFlow::ValidateError => ve
      assert_equal([":miss-me:sort: Missing link for 'float'.",
                    ":miss-me:fix: 'complex' not allowed on ':miss-me:sort'."], ve.problems.map { |p| p.to_s })
    end
    ::OFlow::Env.clear()
  end

  # TBD missing links for output spec


end # FlowCfgErrTest
