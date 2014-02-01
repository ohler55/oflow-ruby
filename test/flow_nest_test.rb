#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

require 'collector'

class Hop < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(task, op, box)
    task.info("#{op} #{box.contents}")
    task.ship(op, box)
  end

end # Hop

class FlowNestTest < ::Test::Unit::TestCase

  def test_flow_nest
    trigger = nil
    collector = nil
    ::OFlow::Env.flow(:nest, :opt1 => 1) { |f|
      # use collector as the log
      f.task(:log, Collector) { |t|
        collector = t.actor
      }

      # starts off the process
      trigger = f.task(:trigger, Hop) { |t|
        t.link(nil, :deep, nil)
      }
      # a nested flow
      f.flow(:deep) { |f2|
        f2.route(nil, :one, nil)
        f2.task(:one, Hop) { |t|
          t.link(nil, :two, nil)
        }
        f2.task(:two, Hop) { |t|
          t.link(nil, :flow, :bye)
        }
        f2.link(:bye, :out, nil)
      }
      f.task(:out, Hop) { |t|
          t.link(nil, :done, nil)
      }
      f.task(:done, ::OFlow::Actors::Ignore)
    }

    # see if the flow was constructed correctly
    assert_equal(%|OFlow::Env {
  nest (OFlow::Flow) {
    log (Collector) {
    }
    trigger (Hop) {
       => deep:
    }
    deep (OFlow::Flow) {
      one (Hop) {
         => two:
      }
      two (Hop) {
         => flow:bye
      }
       * one:
      bye => out:
    }
    out (Hop) {
       => done:
    }
    done (OFlow::Actors::Ignore) {
    }
  }
}|, ::OFlow::Env.describe())

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()
    assert_equal([['go 7', ':nest:trigger'],
                  [' 7', ':nest:deep:one'],
                  [' 7', ':nest:deep:two'],
                  [' 7', ':nest:out']
                 ], collector.collection)

    ::OFlow::Env.clear()
  end

  def test_flow_nest_deep
    trigger = nil
    collector = nil
    ::OFlow::Env.flow(:nest_deep, :opt1 => 1) { |f|
      # use collector as the log
      f.task(:log, Collector) { |t|
        collector = t.actor
      }

      # starts off the process
      trigger = f.task(:trigger, Hop) { |t|
        t.link(nil, :deep, nil)
      }
      # a nested flow
      f.flow(:deep) { |f2|
        f2.route(nil, :deeper, nil)
        f2.flow(:deeper) { |f3|
          f3.route(nil, :one, nil)
          f3.task(:one, Hop) { |t|
            t.link(nil, :two, nil)
          }
          f3.task(:two, Hop) { |t|
            t.link(nil, :flow, :bye)
          }
          f3.link(:bye, :flow, :bye)
        }
        f2.link(:bye, :out, nil)
      }
      f.task(:out, Hop) { |t|
        t.link(nil, :done, nil)
      }
      f.task(:done, ::OFlow::Actors::Ignore)
    }

    # see if the flow was constructed correctly
    assert_equal(%|OFlow::Env {
  nest_deep (OFlow::Flow) {
    log (Collector) {
    }
    trigger (Hop) {
       => deep:
    }
    deep (OFlow::Flow) {
      deeper (OFlow::Flow) {
        one (Hop) {
           => two:
        }
        two (Hop) {
           => flow:bye
        }
         * one:
        bye => flow:bye
      }
       * deeper:
      bye => out:
    }
    out (Hop) {
       => done:
    }
    done (OFlow::Actors::Ignore) {
    }
  }
}|, ::OFlow::Env.describe())

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()
    assert_equal([['go 7', ':nest_deep:trigger'],
                  [' 7', ':nest_deep:deep:deeper:one'],
                  [' 7', ':nest_deep:deep:deeper:two'],
                  [' 7', ':nest_deep:out']
                 ], collector.collection)

    ::OFlow::Env.clear()
  end

  def test_flow_nest_label
    trigger = nil
    collector = nil
    ::OFlow::Env.flow(:nest) { |f|
      # use collector as the log
      f.task(:log, Collector) { |t|
        collector = t.actor
      }

      # starts off the process
      trigger = f.task(:trigger, Hop) { |t|
        t.link(:go, :deep, :first)
      }
      # a nested flow
      f.flow(:deep) { |f2|
        f2.route(:first, :one, :hip)
        f2.task(:one, Hop) { |t|
          t.link(:hip, :two, :hop)
        }
        f2.task(:two, Hop) { |t|
          t.link(:hop, :flow, :get_out)
        }
        f2.link(:get_out, :out, :finish)
      }
      f.task(:out, Hop) { |t|
          t.link(:finish, :done, nil)
      }
      f.task(:done, ::OFlow::Actors::Ignore)
    }

    # run it and check the output
    trigger.receive(:go, ::OFlow::Box.new(7))
    ::OFlow::Env.flush()
    assert_equal([['go 7', ':nest:trigger'],
                  ['hip 7', ':nest:deep:one'],
                  ['hop 7', ':nest:deep:two'],
                  ['finish 7', ':nest:out']
                 ], collector.collection)

    ::OFlow::Env.clear()
  end


end # FlowNestTest
