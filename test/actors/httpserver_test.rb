#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__))

require 'helper'
require 'net/http'
require 'oflow'
require 'oflow/test'

class Reply < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    reply = box.get('request')
    box = box.set('response:body', reply.to_s)
    task.ship(nil, box)
  end

end # Reply

class HttpServerTest < ::MiniTest::Test

  def test_httpserver
    ::OFlow::Env.flow('http-server', port: 6060) { |f|
      f.task('server', ::OFlow::Actors::HttpServer) { |t|
        t.link(nil, :reply, nil)
      }
      f.task(:reply, Reply) { |t|
        t.link(nil, :server, :reply)
      }
    }
    # GET
    uri = URI('http://localhost:6060/test?a=1&b=two')
    reply = Net::HTTP.get(uri)
    assert_equal(%|{:id=>1, :method=>"GET", :protocol=>"HTTP/1.1", :path=>"/test", :args=>[["a", "1"], ["b", "two"]], "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3", "Accept"=>"*/*", "User-Agent"=>"Ruby", "Host"=>"localhost:6060"}|,
                 reply, 'expected reply from GET')

    # POST
    uri = URI('http://localhost:6060/test')
    response = Net::HTTP.post_form(uri, 'a' => '1', 'b' => 'two')
    reply = response.body

    assert_equal(%|{:id=>2, :method=>\"POST\", :protocol=>\"HTTP/1.1\", :path=>\"/test\", :args=>nil, \"Accept-Encoding\"=>\"gzip;q=1.0,deflate;q=0.6,identity;q=0.3\", \"Accept\"=>\"*/*\", \"User-Agent\"=>\"Ruby\", \"Host\"=>\"localhost:6060\", \"Content-Type\"=>\"application/x-www-form-urlencoded\", \"Content-Length\"=>9, :body=>\"a=1&b=two\"}|,
                 reply, 'expected reply from POST')

    ::OFlow::Env.flush()
    ::OFlow::Env.clear()
  end

end # HttpServerTest
