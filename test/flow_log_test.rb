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
    task.warn("op: #{op}, box: #{box.contents}")
    task.ship(nil, ::OFlow::Box.new([box.contents])) if task.has_links?
  end

end # Noise

class FlowLogTest < ::Test::Unit::TestCase

  # Make sure the log works and relays to a log task if it exists.
  def test_flow_log_relay
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
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
    ::OFlow::Env.log_level = Logger::WARN
    ::OFlow::Env.flow('log_var') { |f|
      trigger = f.task('noise', Noise)
      f.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    trigger.receive(:speak, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0], 'op: speak, box: 7')
    assert_equal(collector.collection[0][1], ':log_var:noise')

    ::OFlow::Env.clear()
  end

  # Make sure the log in the Env var is used.
  def test_flow_log_env
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
    ::OFlow::Env.flow('log_env') { |f|
      trigger = f.task('noise', Noise)
      ::OFlow::Env.log = f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    trigger.receive(:speak, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    assert_equal(collector.collection.size, 1)
    assert_equal(collector.collection[0][0], 'op: speak, box: 7')
    assert_equal(collector.collection[0][1], ':log_env:noise')

    ::OFlow::Env.clear()
  end

  def test_flow_log_info
    trigger = nil
    collector = nil
    ::OFlow::Env.log_level = Logger::WARN
    ::OFlow::Env.flow('log_info') { |f|
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
    trigger.receive(:speak, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    entries = collector.collection.map { |entry| entry[0] }
    assert_equal(["Creating actor Noise with options {:state=>1}.",
                  "receive(speak, Box{7}) RUNNING",
                  "perform(speak, Box{7})",
                  "op: speak, box: 7",
                  "shipping Box{[7]} to collector:",
                  7], entries)

    ::OFlow::Env.clear()
    ::OFlow::Env.log_level = Logger::WARN
  end

end # FlowLogTest
