#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

require 'helper'
require 'oflow'
require 'oflow/test'

require 'collector'

class TimerTest < ::MiniTest::Test

  def test_timer_period_repeat
    env = ::OFlow::Env.new('')
    period = 0.1
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 4, period: period) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    env.flush()
    prev = nil
    ticks = collector.collection.map do |t|
      tf = t[2].to_f
      if prev.nil?
        tick = [t[1], tf, 0.0]
      else
        tick = [t[1], tf, tf - prev]
      end
      prev = tf
      tick
    end
    
    ticks.size.times do |i|
      tick = ticks[i]
      assert_equal(i + 1, tick[0])
      next if 0 == i
      dif = tick[2] - period
      limit = period / 10 # 10% accuracy
      assert(-limit < dif && dif < limit, "Verify timer fires are within 10% of expected. (dif: #{dif}, limit: #{limit})")
    end

    env.clear()
  end

  def test_timer_options_start
    now = Time.now()
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, start: now, state: ::OFlow::Task::BLOCKED)
    assert_equal(now, t.actor.start, 'is the start time now?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, start: nil, state: ::OFlow::Task::BLOCKED)
    assert_equal(Time, t.actor.start.class, 'is the start time a Time?')
    assert(0.1 > (Time.now() - t.actor.start), 'is the start time now?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, start: 2, state: ::OFlow::Task::BLOCKED)
    assert_equal(Time, t.actor.start.class, 'is the start time a Time?')
    assert(0.1 > (Time.now() + 2 - t.actor.start), 'is the start time now + 2?')

    assert_raises(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, start: 'now')
    end
  end

  def test_timer_options_stop
    now = Time.now()
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, stop: now, state: ::OFlow::Task::BLOCKED)
    assert_equal(now, t.actor.stop, 'is the stop time now?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, stop: nil, state: ::OFlow::Task::BLOCKED)
    assert_equal(nil, t.actor.stop, 'is the stop time nil?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, stop: 2, state: ::OFlow::Task::BLOCKED)
    assert_equal(Time, t.actor.stop.class, 'is the stop time a Time?')
    assert(0.1 > (Time.now() + 2 - t.actor.stop), 'is the stop time now + 2?')

    assert_raises(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, stop: 'now')
    end
  end

  def test_timer_options_period
    assert_raises(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, period: nil, state: ::OFlow::Task::BLOCKED)
    end
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, period: 2, state: ::OFlow::Task::BLOCKED)
    assert_equal(2, t.actor.period, 'is the period 2?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, period: 2.0, state: ::OFlow::Task::BLOCKED)
    assert_equal(2.0, t.actor.period, 'is the period 2.0?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, period: "2.5", state: ::OFlow::Task::BLOCKED)
    assert_equal(2.5, t.actor.period, 'is the period 2.5?')

    assert_raises(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, period: 'now')
    end
  end

  def test_timer_options_repeat
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, repeat: nil, state: ::OFlow::Task::BLOCKED)
    assert_equal(nil, t.actor.repeat, 'is the repeat nil?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, repeat: 2, state: ::OFlow::Task::BLOCKED)
    assert_equal(2, t.actor.repeat, 'is the repeat 2?')

    assert_raises(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, repeat: 2.0)
    end
  end

  def test_timer_options_with_tracker
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, with_tracker: nil, state: ::OFlow::Task::BLOCKED)
    assert_equal(false, t.actor.with_tracker, 'is the with_tracker false?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, with_tracker: false, state: ::OFlow::Task::BLOCKED)
    assert_equal(false, t.actor.with_tracker, 'is the with_tracker false?')

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, with_tracker: true, state: ::OFlow::Task::BLOCKED)
    assert_equal(true, t.actor.with_tracker, 'is the with_tracker true?')

    assert_raises(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, with_tracker: 'now')
    end

    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, with_tracker: true, repeat: 2, label: 'fast')
    assert_equal(2, t.history.size, 'are there 2 items in the history?')
    assert_equal(false, t.history[0].box.tracker.nil?, 'is there a tracker on the box that shipped?')
  end

  def test_timer_repeat
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, repeat: 2, label: 'fast')
    assert_equal(2, t.history.size, 'are there 2 items in the history?')
  end

  def test_timer_time
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, stop: 2, period: 0.5, label: 'time')
    assert_equal(4, t.history.size, 'are there 4 items in the history?')
  end

  def test_timer_perform_period
    env = ::OFlow::Env.new('')
    period = 0.1
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 2, period: 2) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    timer.receive(:period, ::OFlow::Box.new(period))
    env.flush()
    prev = nil
    ticks = collector.collection.map do |t|
      tf = t[2].to_f
      if prev.nil?
        tick = [t[1], tf, 0.0]
      else
        tick = [t[1], tf, tf - prev]
      end
      prev = tf
      tick
    end
    
    ticks.size.times do |i|
      tick = ticks[i]
      assert_equal(i + 1, tick[0])
      next if 0 == i
      dif = tick[2] - period
      limit = period / 10 # 10% accuracy
      assert(-limit < dif && dif < limit, "Verify timer fires are within 10% of expected. (dif: #{dif}, limit: #{limit})")
    end

    env.clear()
  end

  def test_timer_perform_repeat
    env = ::OFlow::Env.new('')
    repeat = 2
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 4, period: 0.1) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    timer.receive(:repeat, ::OFlow::Box.new(repeat))
    env.flush()
    assert_equal(2, collector.collection.size)

    env.clear()
  end

  def test_timer_perform_start
    env = ::OFlow::Env.new('')
    now = Time.now()
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 1, period: 0.1, start: 2) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    timer.receive(:start, ::OFlow::Box.new(nil))
    env.flush()
    first_fire = collector.collection[0][2] - now
    assert(0.01 > first_fire, "first fire was at #{first_fire}, expected less than 0.01 msecs?")

    env.clear()
  end

  def test_timer_perform_stop
    env = ::OFlow::Env.new('')
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 10, period: 0.1, stop: 2) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    timer.receive(:stop, ::OFlow::Box.new(0.25))
    env.flush()
    assert_equal(3, collector.collection.size)

    env.clear()
  end

  def test_timer_perform_label
    env = ::OFlow::Env.new('')
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 2, period: 0.1, label: 'first') { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    timer.receive(:label, ::OFlow::Box.new('second'))
    env.flush()
    assert_equal(['first', 'second'], collector.collection.map { |x| x[0] })

    env.clear()
  end

  def test_timer_perform_tracker
    env = ::OFlow::Env.new('')
    timer = nil
    collector = nil
    env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 2, period: 0.1, with_tracker: false) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector, contents_only: false) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    timer.receive(:with_tracker, ::OFlow::Box.new(true))
    env.flush()
    assert_equal([false, true], collector.collection.map { |x| !x.tracker.nil? })

    env.clear()
  end

end # TimerTest
