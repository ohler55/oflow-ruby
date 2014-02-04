#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

require 'collector'

class Throw < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.ship(op, box)
  end

end # Throw

class Catch < ::OFlow::Actor
  attr_reader :ball

  def initialize(task, options)
    super
    @ball = nil
  end

  def perform(op, box)
    @ball = box
  end

end # Catch

class FlowTrackerTest < ::Test::Unit::TestCase

  def test_flow_tracker
    trigger = nil
    catcher = nil
    ::OFlow::Env.flow(:nest, :opt1 => 1) { |f|

      # starts off the process
      trigger = f.task(:trigger, Throw) { |t|
        t.link(nil, :deep, nil)
      }
      # a nested flow
      f.flow(:deep) { |f2|
        f2.route(nil, :one, nil)
        f2.task(:one, Throw) { |t|
          t.link(nil, :two, nil)
        }
        f2.task(:two, Throw) { |t|
          t.link(nil, :flow, :bye)
        }
        f2.link(:bye, :out, nil)
      }
      f.task(:out, Throw) { |t|
          t.link(nil, :done, nil)
      }
      catcher = f.task(:done, Catch)
    }

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7, ::OFlow::Tracker.new('test')))
    ::OFlow::Env.flush()
    assert_equal(["test-",
                  ":nest:trigger-go",
                  ":nest:deep-",
                  ":nest:deep:one-",
                  ":nest:deep:two-",
                  ":nest:deep-bye",
                  ":nest:out-",
                  ":nest:done-"], catcher.actor.ball.tracker.track.map {|s| s.where })

    ::OFlow::Env.clear()
  end

end # FlowTrackerTest
