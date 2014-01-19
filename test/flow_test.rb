#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

class Collector < ::OFlow::Actor
  attr_reader :collection

  def initialize(task, options)
    super
    @collection = []
  end

  def perform(task, op, box)
    @collection << box.contents
  end

end # Collector

class Stutter < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(task, op, box)
    task.ship(:collector, ::OFlow::Box.new([task.full_name, op, box.contents]))
    task.ship(op, box)
  end

end # Stutter

class Noise < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(task, op, box)
    task.info("op: #{op}, box: #{box.contents}")
  end

end # Stutter

class Crash < ::OFlow::Actor
  def initialize(task, options)
    super
  end

  def perform(task, op, box)
    nil.crash()
  end

end # Stutter

class FlowTest < ::Test::Unit::TestCase

  def test_flow_basic
    trigger = nil
    collector = nil
    ::OFlow::Env.flow('basic', :opt1 => 1) { |f|
      # collects results
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
      # starts off the process
      trigger = f.task('trigger', Stutter) { |t|
        t.link(:collector, 'collector', 'trigger')
        t.link(:once, 'dub', :twice)
      }
      # sends to self and then ends with no other task to ship to
      f.task('dub', Stutter, :opt1 => 7) { |t|
        t.link(:collector, 'collector', 'dub')
        t.link(:twice, 'dub', :once)
        t.link(:once, 'ignore', nil)
      }
      f.task(:ignore, ::OFlow::Ignore)
    }
    # see if the flow was constructed correctly
    assert_equal(%|OFlow::Env {
  basic (OFlow::Flow) {
    collector (Collector) {
    }
    trigger (Stutter) {
      collector => collector:trigger
      once => dub:twice
    }
    dub (Stutter) {
      collector => collector:dub
      twice => dub:once
      once => ignore:
    }
    ignore (OFlow::Ignore) {
    }
  }
}
|, ::OFlow::Env.describe())

    # run it and check the output
    trigger.receive(:once, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()
    assert_equal([[':basic:trigger', :once, 7],
                  [':basic:dub', :twice, 7],
                  [':basic:dub', :once, 7],
                 ], collector.collection)

    ::OFlow::Env.clear()
  end

  # Make sure the error handler works and forwards to the 'error' task if it
  # exists.
  def test_flow_rescue
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

end # FlowTest
