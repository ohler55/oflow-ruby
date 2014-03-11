#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "..")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'
require 'oflow/test'

require 'gserver'
require 'xmlrpc/httpserver'

class Reply < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    box = box.set('response:body', 'Hello')
    task.ship(nil, box)
  end

end # Reply

class HttpServerTest < ::Test::Unit::TestCase

  def test_httpserver
    ::OFlow::Env.flow('http-server', port: 6060) { |f|
      f.task('server', ::OFlow::Actors::HttpServer) { |t|
        t.link(nil, :reply, nil)
      }
      f.task(:reply, Reply) { |t|
        t.link(nil, :server, :reply)
      }
    }
    sleep(20)
    ::OFlow::Env.flush()
    ::OFlow::Env.clear()
  end

end # HttpServerTest
