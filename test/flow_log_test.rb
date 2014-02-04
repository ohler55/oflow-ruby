#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

require 'collector'

class Noise < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.info("op: #{op}, box: #{box.contents}")
  end

end # Noise

class FlowLogTest < ::Test::Unit::TestCase

  # Make sure the log works and relays to a log task if it exists.
  def test_flow_log_relay
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('log_relay') { |f|
      trigger = f.task('noise', Noise)
      f.task(:log, Collector) { |t|
        collector = t.actor
      }
    }
    trigger.receive(:speak, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0], 'op: speak, box: 7')
    assert_equal(collector.collection[0][1], ':log_relay:noise')

    ::OFlow::Env.clear()
  end

  # Make sure the log in the flow var is used.
  def test_flow_log_var
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('log_relay') { |f|
      trigger = f.task('noise', Noise)
      f.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    trigger.receive(:speak, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0], 'op: speak, box: 7')
    assert_equal(collector.collection[0][1], ':log_relay:noise')

    ::OFlow::Env.clear()
  end

  # Make sure the log in the Env var is used.
  def test_flow_log_env
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('log_relay') { |f|
      trigger = f.task('noise', Noise)
      ::OFlow::Env.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    trigger.receive(:speak, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0], 'op: speak, box: 7')
    assert_equal(collector.collection[0][1], ':log_relay:noise')

    ::OFlow::Env.clear()
  end

end # FlowLogTest
