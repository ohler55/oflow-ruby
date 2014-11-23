#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'helper'
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

class FlowTrackerTest < ::MiniTest::Test

  def test_flow_tracker
    env = ::OFlow::Env.new('')
    trigger = nil
    catcher = nil
    env.flow(:prime) { |f|
      # starts off the process
      trigger = f.task(:trigger, Throw) { |t|
        t.link(nil, :one, nil, :deep)
      }
      f.task(:in, Throw) { |t|
          t.link(nil, :done, nil)
      }
      catcher = f.task(:done, Catch)
    }
    env.flow(:deep) { |f|
      f.task(:one, Throw) { |t|
        t.link(nil, :two, nil)
      }
      f.task(:two, Throw) { |t|
        t.link(nil, :in, :bye, :prime)
      }
    }

    env.prepare()
    env.start()

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7, ::OFlow::Tracker.create('test')))
    env.flush()
    assert_equal(["test-",
                  "prime:trigger-go",
                  "deep:one-",
                  "deep:two-",
                  "prime:in-bye",
                  "prime:done-"], catcher.actor.ball.tracker.track.map {|s| s.where })

    env.clear()
  end

end # FlowTrackerTest
