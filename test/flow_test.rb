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
    @collector_link = nil
    @once_link = nil
    @twice_link = nil
  end

  def perform(task, op, box)
    # TBD later use links
    task.ship(:collector, ::OFlow::Box.new([task.full_name, op, box.contents]))
    task.ship(op, box)
  end

end # Stutter

class Crash < ::OFlow::Actor
  def initialize(task, options)
    super
  end

  def perform(task, op, box)
    puts "*** crash"
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
        # TBD t.link(:once, 'ignore', nil)
      }
      # TBD set error task to collector (support aliases)
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

  def test_flow_rescue
    trigger = nil
    ::OFlow::Env.flow('rescue') { |f|
      trigger = f.task('crash', Crash)
    }
    trigger.receive(:knock, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()

    ::OFlow::Env.clear()
  end

end # FlowTest
