#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

class Keeper < ::OFlow::Actor
  attr_accessor :keep

  def initialize(task, options)
    super
    @keep = options[:keep] || []
  end

  def perform(task, op, box)
    @keep << [task.name, op, box.contents]
    task.ship(op, box)
  end

end # Keeper

class FlowTest < ::Test::Unit::TestCase

  def test_flow_basic
    kept = []
    trigger = nil
    ::OFlow::Env.flow('basic', :opt1 => 1) { |f|
      # starts off the process
      trigger = f.task('trigger', Keeper, :keep => kept) { |t|
        t.link(:once, 'stutter', :twice)
      }
      # sends to self and then ends with no other task to ship to
      f.task('stutter', Keeper, :keep => kept) { |t|
        t.link(:twice, 'stutter', :once)
      }
    }
    # trigger.ship(:once, ::OFlow::Box.new(7))

    # TBD wait for finish and check kept
  end

  # TBD flow directlry on Env

end # FlowTest
