#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'helper'
require 'oflow'

require 'collector'

class Noise < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.warn("op: #{op}, box: #{box.contents}")
    task.ship(nil, ::OFlow::Box.new([box.contents])) if task.has_links?
  end

end # Noise

class FlowLogTest < ::MiniTest::Test

  # Make sure the log works and relays to a log task if it exists.
  def test_flow_log_relay
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
    env.flow('log_relay') { |f|
      trigger = f.task('noise', Noise)
      f.task(:log, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:speak, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal('op: speak, box: 7', collector.collection[0][0])
    assert_equal('log_relay:noise', collector.collection[0][1])

    env.clear()
  end

  # Make sure the log in the flow var is used.
  def test_flow_log_var
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
    env.flow('log_var') { |f|
      trigger = f.task('noise', Noise)
      f.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:speak, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal('op: speak, box: 7', collector.collection[0][0])
    assert_equal('log_var:noise', collector.collection[0][1])

    env.clear()
  end

  # Make sure the log in the Env var is used.
  def test_flow_log_env
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
    env.flow('log_env') { |f|
      trigger = f.task('noise', Noise)
      env.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:speak, ::OFlow::Box.new(7))
    env.flush()

    assert_equal(1, collector.collection.size)
    assert_equal('op: speak, box: 7', collector.collection[0][0])
    assert_equal('log_env:noise', collector.collection[0][1])

    env.clear()
  end

  def test_flow_log_info
    env = ::OFlow::Env.new('')
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
    env.flow('log_info') { |f|
      f.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      # Set after log to avoid race condition with the creation of the collector
      # and the assignment to f.log. The race is whether a log message is
      # displayed on the output.
    ::OFlow::Env.log_level = Logger::INFO
      trigger = f.task('noise', Noise) { |t|
        t.link(nil, :collector, nil)
      }
    }
    env.prepare()
    env.start()

    trigger.receive(:speak, ::OFlow::Box.new(7))
    env.flush()

    entries = collector.collection.map { |entry| entry[0] }
    assert_equal(["Creating actor Noise with options {:state=>1}.",
                  "receive(speak, Box{7}) RUNNING",
                  "perform(speak, Box{7})",
                  "op: speak, box: 7",
                  "shipping Box{[7]} to collector:",
                  7], entries)

    env.clear()
    ::OFlow::Env.log_level = Logger::WARN
  end

end # FlowLogTest
