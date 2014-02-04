#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "..")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

require 'collector'

class TimerTest < ::Test::Unit::TestCase

  def test_timer_repeat
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

  # TBD more tests on start, stop, combinations of options, and error conditions

end # TimerTest
