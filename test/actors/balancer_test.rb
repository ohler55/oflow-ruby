#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

require 'helper'
require 'oflow'
require 'oflow/test'

require 'collector'

class Busy < ::OFlow::Actor
  
  def initialize(task, options)
    super
    @delay = options.fetch(:delay, 0)
  end

  def perform(op, box)
    if 0.0 < @delay
      done = Time.now() + @delay
      while true
        now = Time.now()
        break if done <= now
        sleep(done - now)
      end
    end
    task.ship(nil, ::OFlow::Box.new([task.name, box.contents]))
  end

end # Busy

class BalancerTest < ::MiniTest::Test

  def test_balancer_fair
    env = ::OFlow::Env.new('')
    balancer = nil
    collector = nil
    env.flow('fair') { |f|
      f.task('balance', ::OFlow::Actors::Balancer) { |t|
        balancer = t
        t.link(:one, :one, nil)
        t.link(:two, :two, nil)
        t.link(:three, :three, nil)
      }
      f.task(:one, Busy) { |t|
        t.link(nil, :collector, :one)
      }
      f.task(:two, Busy) { |t|
        t.link(nil, :collector, :two)
      }
      f.task(:three, Busy) { |t|
        t.link(nil, :collector, :three)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    9.times { |i| balancer.receive(nil, ::OFlow::Box.new(i)) }
    env.flush()
    counts = {}
    collector.collection.each { |a| counts[a[0]] = counts.fetch(a[0], 0) + 1 }

    assert_equal(counts[:one], counts[:two], 'all counts should be the same')
    assert_equal(counts[:two], counts[:three], 'all counts should be the same')

    env.clear()
  end

  def test_balancer_less_busy
    env = ::OFlow::Env.new('')
    balancer = nil
    collector = nil
    env.flow('less-busy') { |f|
      f.task('balance', ::OFlow::Actors::Balancer) { |t|
        balancer = t
        t.link(:one, :one, nil)
        t.link(:two, :two, nil)
        t.link(:three, :three, nil)
      }
      f.task(:one, Busy, delay: 0.01) { |t|
        t.link(nil, :collector, :one)
      }
      f.task(:two, Busy, delay: 0.02) { |t|
        t.link(nil, :collector, :two)
      }
      f.task(:three, Busy, delay: 0.04) { |t|
        t.link(nil, :collector, :three)
      }
      f.task(:collector, Collector) { |t|
        collector = t.actor
      }
    }
    env.prepare()
    env.start()

    40.times { |i| balancer.receive(nil, ::OFlow::Box.new(i)); sleep(0.005) }
    env.flush()
    counts = {}
    collector.collection.each { |a| counts[a[0]] = counts.fetch(a[0], 0) + 1 }
    #puts "*** #{counts}"

    assert(counts[:one] > counts[:two], 'one is faster and should have processed more than two')
    assert(counts[:two] > counts[:three], 'two is faster and should have processed more than three')

    env.clear()
  end

end # BalancerTest
