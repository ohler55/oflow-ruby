#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

require 'collector'

class Stutter < ::OFlow::Actor
  
  def initialize(task, options)
    super
    @collector = nil
  end

  def perform(task, op, box)
    if @collector.nil?
      @collector = task.ship(:collector, ::OFlow::Box.new([task.full_name, op, box.contents]))
    else
      @collector.ship(::OFlow::Box.new([task.full_name, op, box.contents, 'with_link']))
    end
    task.ship(op, box)
  end

end # Stutter

class FlowBasicTest < ::Test::Unit::TestCase

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
}|, ::OFlow::Env.describe())

    # run it and check the output
    trigger.receive(:once, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()
    assert_equal([[':basic:trigger', :once, 7],
                  [':basic:dub', :twice, 7],
                  [':basic:dub', :once, 7, 'with_link'],
                 ], collector.collection)

    # run again and make sure all tasks use links
    collector.collection = []
    trigger.receive(:once, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()
    assert_equal([[':basic:trigger', :once, 7, 'with_link'],
                  [':basic:dub', :twice, 7, 'with_link'],
                  [':basic:dub', :once, 7, 'with_link'],
                 ], collector.collection)

    ::OFlow::Env.clear()
  end

end # FlowBasicTest
