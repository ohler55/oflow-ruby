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

class TimerTest < ::Test::Unit::TestCase

  def test_timer_period_repeat
    period = 0.1
    timer = nil
    collector = nil
    ::OFlow::Env.flow('one-time') { |f|
      f.task('once', ::OFlow::Actors::Timer, repeat: 4, period: period) { |t|
        timer = t
        t.link(:ping, :collector, :tick)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    ::OFlow::Env.flush()
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

    ::OFlow::Env.clear()
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

    assert_raise(::OFlow::ConfigError) do
      ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Timer, start: 'now')
    end
  end

  def test_timer_options_stop
    # TBD
  end

  def test_timer_options_period
    # TBD
  end

  def test_timer_options_repeat
    # TBD
  end

  def test_timer_options_with_tracker
    # TBD
    #  with tracker, verify a tracker is added
  end

  def test_timer_repeat
    # TBD
  #  nil period and limited repeat
  end

  def test_timer_time
    # TBD
  #  start and stop time with fixed period (count number of callbacks)
  end

end # TimerTest
