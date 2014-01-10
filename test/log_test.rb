#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'stringio'
require 'oflow'

class LogTest < ::Test::Unit::TestCase

  def test_log
    stream = StringIO.new()
    log = ::OFlow::Task.new(nil, 'log', ::OFlow::Log,
                            :stream => stream,
                            :severity => Logger::INFO,
                            :formatter => proc { |sev, time, prog, msg| "#{sev}: #{msg}\n" })

    log.receive(:fatal, ::OFlow::Box.new(['Dead', 'dead']))
    log.receive(:error, ::OFlow::Box.new(['Oops', 'oops']))
    log.receive(:warn, ::OFlow::Box.new(['Duck', 'duck']))
    log.receive(:info, ::OFlow::Box.new(['Something', 'something']))
    log.receive(:debug, ::OFlow::Box.new(['Bugs', 'bugs']))

    log.flush()
    assert_equal(%{FATAL: dead
ERROR: oops
WARN: duck
INFO: something
}, stream.string)

    log.shutdown()
  end

end # LogTest
