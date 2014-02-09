#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "..")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'
require 'oflow/test'

require 'collector'

class Splitter < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.ship(:left, box)
    task.ship(:right, box)
  end

end # Splitter

class Multiplier < ::OFlow::Actor
  
  def initialize(task, options)
    super
    @factor = options.fetch(:factor, 1)
  end

  def perform(op, box)
    box = box.set(nil, box.contents * @factor)
    task.ship(nil, box)
  end

end # Multiplier

class MergerTest < ::Test::Unit::TestCase

  def test_merger_any
    start = nil
    collector = nil
    ::OFlow::Env.flow('merge') { |f|
      f.task(:split, Splitter) { |t|
        start = t
        t.link(:left, :one, nil)
        t.link(:right, :two, nil)
      }
      f.task(:one, Multiplier, factor: 2) { |t|
        t.link(nil, :merge, nil)
      }
      f.task(:two, Multiplier, factor: 3) { |t|
        t.link(nil, :merge, nil)
      }
      f.task(:merge, ::OFlow::Actors::Merger) { |t|
        t.link(nil, :collector, nil)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    start.receive(nil, ::OFlow::Box.new(1))
    ::OFlow::Env.flush()

    result = collector.collection[0]
    assert_equal(2, result.size, 'should be 2 values in the box')
    assert(result.include?(2), 'box should include 2')
    assert(result.include?(3), 'box should include 3')

    ::OFlow::Env.clear()
  end

  def test_merger_tracker
    start = nil
    collector = nil
    ::OFlow::Env.flow('merge') { |f|
      f.task(:split, Splitter) { |t|
        start = t
        t.link(:left, :one, nil)
        t.link(:right, :two, nil)
      }
      f.task(:one, Multiplier, factor: 2) { |t|
        t.link(nil, :merge, nil)
      }
      f.task(:two, Multiplier, factor: 3) { |t|
        t.link(nil, :merge, nil)
      }
      f.task(:merge, ::OFlow::Actors::Merger) { |t|
        t.link(nil, :collector, nil)
      }
      f.task(:collector, Collector, contents_only: false) { |t|
        collector = t.actor
      }
    }
    tracker = ::OFlow::Tracker.create('start')
    start.receive(nil, ::OFlow::Box.new(1, tracker))
    tracker2 = ::OFlow::Tracker.create('start2')
    start.receive(nil, ::OFlow::Box.new(10, tracker2))
    ::OFlow::Env.flush()

    box = collector.collection[0]
    result = box.contents
    assert_equal(2, result.size, 'should be 2 values in the box')
    assert(result.include?(2), 'box should include 2')
    assert(result.include?(3), 'box should include 3')
    
    t = box.tracker()
    assert_not_nil(t, 'should have a tracker')
    assert_equal(t.id, tracker.id, 'tracker id should be carried through')
    track = t.track
    
    assert_equal('start', track[0].location)
    assert_equal(':merge:split', track[1].location)
    split = track[2].map { |a| a.map { |stamp| stamp.location } }

    assert_equal(2, split.size, 'should be 2 values in the split')
    assert(split.include?([':merge:one']), 'split should include [merge:one]')
    assert(split.include?([':merge:two']), 'split should include [merge:two]')
    assert_equal(':merge:merge', track[3].location)
    assert_equal(':merge:collector', track[4].location)

    box = collector.collection[1]
    result = box.contents
    assert_equal(2, result.size, 'should be 2 values in the box')
    assert(result.include?(20), 'box should include 20')
    assert(result.include?(30), 'box should include 30')

    ::OFlow::Env.clear()
  end

end # MergerTest
