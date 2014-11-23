#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

require 'helper'
require 'stringio'
require 'oflow'

class LogTest < ::MiniTest::Test

  def test_log
    stream = StringIO.new()
    log = ::OFlow::Task.new(nil, 'log', ::OFlow::Actors::Log,
                            :stream => stream,
                            :severity => Logger::INFO,
                            :formatter => proc { |sev, time, prog, msg| "#{sev}: #{msg}\n" })

    log.receive(:fatal, ::OFlow::Box.new(['dead msg', 'Dead']))
    log.receive(:error, ::OFlow::Box.new(['oops msg', 'Oops']))
    log.receive(:warn, ::OFlow::Box.new(['duck msg', 'Duck']))
    log.receive(:info, ::OFlow::Box.new(['something msg', 'Something']))
    log.receive(:debug, ::OFlow::Box.new(['bugs msg', 'Bugs']))

    log.flush()
    assert_equal(%{FATAL: dead msg
ERROR: oops msg
WARN: duck msg
INFO: something msg
}, stream.string)

    log.shutdown()
  end

  def test_log_filename
    filename = 'filename_test.log'
    %x{rm -f #{filename}}

    log = ::OFlow::Task.new(nil, 'log', ::OFlow::Actors::Log,
                            :filename => filename,
                            :severity => Logger::INFO,
                            :formatter => proc { |sev, time, prog, msg| "#{sev}: #{msg}\n" })

    log.receive(:info, ::OFlow::Box.new(['first entry', 'One']))
    log.flush()

    output = File.read(filename).split("\n")[1..-1]
    assert_equal(['INFO: first entry'], output)
    %x{rm #{filename}}

    log.shutdown()
  end

end # LogTest
