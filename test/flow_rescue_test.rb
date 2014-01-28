#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

class Crash < ::OFlow::Actor
  def initialize(task, options)
    super
  end

  def perform(task, op, box)
    nil.crash()
  end

end # Crash

class FlowRescueTest < ::Test::Unit::TestCase

  # Make sure the error handler works and forwards to the 'error' task if it
  # exists.
  def test_flow_rescue_task
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:error, ::OFlow::Relay) { |t|
        t.link(nil, 'collector', 'error')
      }
      f.task(:log, ::OFlow::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    trigger.receive(:knock, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0].class, NoMethodError)
    assert_equal(collector.collection[0][1], ':rescue:crash')

    ::OFlow::Env.clear()
  end

  # Make sure the error handler on the flow is used to handle errors.
  def test_flow_rescue_var
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      f.error_handler = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:log, ::OFlow::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    trigger.receive(:knock, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0].class, NoMethodError)
    assert_equal(collector.collection[0][1], ':rescue:crash')

    ::OFlow::Env.clear()
  end

  # Make sure the error handler on the flow is used to handle errors.
  def test_flow_rescue_env
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      ::OFlow::Env.error_handler = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:log, ::OFlow::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    trigger.receive(:knock, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal(NoMethodError, collector.collection[0][0].class)
    assert_equal(':rescue:crash', collector.collection[0][1])

    ::OFlow::Env.clear()
  end

  # Make sure the default error handler on the flow passes a message to the log.
  def test_flow_rescue_env_log
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
      ::OFlow::Env.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      f.task(:log, ::OFlow::Relay) { |t|
        t.link(nil, 'collector', 'log')
      }
    }
    trigger.receive(:knock, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal([%|NoMethodError: undefined method `crash' for nil:NilClass
    /Users/ohler/git/oflow-ruby/test/flow_rescue_test.rb:17:in `perform'
    /Users/ohler/git/oflow-ruby/lib/oflow/task.rb:70:in `block in initialize'|,
                  ':rescue:crash'], collector.collection[0])

    ::OFlow::Env.clear()
  end

end # FlowRescueTest
