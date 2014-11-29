#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'oflow'

class HelloWorld < ::OFlow::Actor
  def initialize(task, options)
    super
  end

  def perform(op, box)
    puts 'Hello World!'
  end

end # HelloWorld

def hello_flow(period)
    $oflow_env.flow('hello_world') { |f|
      f.task(:repeater, ::OFlow::Actors::Timer, repeat: 10, period: period) { |t|
        t.link(nil, :hello, nil)
      }
      f.task(:hello, HelloWorld)
    }
end

hello_flow(1.0)

if $0 == __FILE__
  $oflow_env.flush()
end
