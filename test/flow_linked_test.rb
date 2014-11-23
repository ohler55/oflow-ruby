#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'helper'
require 'oflow'

require 'collector'

class Hop < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.warn("#{op} #{box.contents}")
    task.ship(op, box)
  end

end # Hop

class FlowLinkedTest < ::MiniTest::Test

  def test_flow_linked
    env = ::OFlow::Env.new('')
    env.log = ::OFlow::Task.new(env, :log, Collector)
    trigger = nil

    env.flow(:prime) { |f|
      # starts off the process
      trigger = f.task(:trigger, Hop) { |t|
        t.link(nil, :one, nil, :linked)
      }
      f.task(:in, Hop) { |t|
          t.link(nil, :done, nil)
      }
      f.task(:done, ::OFlow::Actors::Ignore)
    }
    env.flow(:linked) { |f|
      f.task(:one, Hop) { |t|
        t.link(nil, :two, nil)
      }
      f.task(:two, Hop) { |t|
        t.link(nil, :in, :bye, :prime)
      }
    }
    env.prepare()
    env.start()

    # see if the flow was constructed correctly
    assert_equal(%| (OFlow::Env) {
  prime (OFlow::Flow) {
    trigger (Hop) {
       => linked:one:
    }
    in (Hop) {
       => :done:
    }
    done (OFlow::Actors::Ignore) {
    }
  }
  linked (OFlow::Flow) {
    one (Hop) {
       => :two:
    }
    two (Hop) {
       => prime:in:bye
    }
  }
}|, env.describe())

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7))
    env.flush()
    assert_equal([['go 7', 'prime:trigger'],
                  [' 7', 'linked:one'],
                  [' 7', 'linked:two'],
                  ['bye 7', 'prime:in']
                 ], env.log.actor.collection)

    env.clear()
  end

  def test_flow_linked_label
    env = ::OFlow::Env.new('')
    env.log = ::OFlow::Task.new(env, :log, Collector)
    trigger = nil

    env.flow(:prime) { |f|
      # starts off the process
      trigger = f.task(:trigger, Hop) { |t|
        t.link(:go, :one, :hip, :linked)
      }
      f.task(:in, Hop) { |t|
          t.link(:bye, :done, nil)
      }
      f.task(:done, ::OFlow::Actors::Ignore)
    }
    env.flow(:linked) { |f|
      f.task(:one, Hop) { |t|
        t.link(:hip, :two, :hop)
      }
      f.task(:two, Hop) { |t|
        t.link(:hop, :in, :bye, :prime)
      }
    }
    env.prepare()
    env.start()

    # see if the flow was constructed correctly
    assert_equal(%| (OFlow::Env) {
  prime (OFlow::Flow) {
    trigger (Hop) {
      go => linked:one:hip
    }
    in (Hop) {
      bye => :done:
    }
    done (OFlow::Actors::Ignore) {
    }
  }
  linked (OFlow::Flow) {
    one (Hop) {
      hip => :two:hop
    }
    two (Hop) {
      hop => prime:in:bye
    }
  }
}|, env.describe())

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7))
    env.flush()
    assert_equal([['go 7', 'prime:trigger'],
                  ['hip 7', 'linked:one'],
                  ['hop 7', 'linked:two'],
                  ['bye 7', 'prime:in']
                 ], env.log.actor.collection)

    env.clear()
  end

end # FlowLinkedTest
