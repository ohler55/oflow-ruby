#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'helper'
require 'oflow'

require 'collector'

class Crash < ::OFlow::Actor
  def initialize(task, options)
    super
  end

  def perform(op, box)
    nil.crash()
  end

end # Crash

class FlowRescueTest < ::MiniTest::Test

  # Make sure the error handler works and forwards to the 'error' task if it
  # exists.
  def test_flow_rescue_task
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:error, ::OFlow::Actors::Relay) { |t|
        t.link(nil, 'collector', 'error')
      }
      f.task(:log, ::OFlow::Actors::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:knock, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal(NoMethodError, collector.collection[0][0].class)
    assert_equal('rescue:crash', collector.collection[0][1])

    env.clear()
  end

  # Make sure the error handler on the flow is used to handle errors.
  def test_flow_rescue_var
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      f.error_handler = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:log, ::OFlow::Actors::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:knock, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal(NoMethodError, collector.collection[0][0].class)
    assert_equal('rescue:crash', collector.collection[0][1])

    env.clear()
  end

  # Make sure the error handler on the flow is used to handle errors.
  def test_flow_rescue_env
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      env.error_handler = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:log, ::OFlow::Actors::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:knock, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal(NoMethodError, collector.collection[0][0].class)
    assert_equal('rescue:crash', collector.collection[0][1])

    env.clear()
  end

  # Make sure the default error handler on the flow passes a message to the log.
  def test_flow_rescue_env_log
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      env.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:knock, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal(["NoMethodError: undefined method `crash' for nil:NilClass",
                  "/flow_rescue_test.rb:0:in `perform'",
                  "/task.rb:0:in `block in initialize'"],
                 simplify(collector.collection[0][0]))

    assert_equal('rescue:crash', collector.collection[0][1])

    env.clear()
  end

  def simplify(bt)
    bt.split("\n").map do |line|
      i = line.index(/\/\w+\.rb\:\d+/)
      unless i.nil?
        line = line[i..-1]
      end
      line.gsub(/\d+/, '0')
    end
  end

end # FlowRescueTest
