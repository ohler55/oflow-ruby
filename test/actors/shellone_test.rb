#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

require 'helper'
require 'oflow'
require 'oflow/test'

class ShellOneTest < ::MiniTest::Test

  def test_shellone_config
    root_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::ShellOne, state: ::OFlow::Task::BLOCKED,
                                     dir: 'somewhere',
                                     cmd: 'pwd',
                                     timeout: 0.5)
    assert_equal(File.join(root_dir, 'somewhere'), t.actor.dir, 'dir set from options')
    assert_equal('pwd', t.actor.cmd, 'cmd set from options')
    assert_equal(0.5, t.actor.timeout, 'timeout set from options')
  end

  def test_shellone_simple
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::ShellOne, state: ::OFlow::Task::BLOCKED,
                                     dir: 'actors',
                                     cmd: './doubler.rb',
                                     timeout: 0.5)
    t.receive(nil, ::OFlow::Box.new([1,2,3]))
    assert_equal(1, t.history.size, 'one entry should be in the history')

    assert_equal([2,4,6], t.history[0].box.contents, 'should  have correct contents in shipment')
  end

  def test_shellone_bad
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::ShellOne, state: ::OFlow::Task::BLOCKED,
                                     dir: 'actors',
                                     cmd: './bad.rb',
                                     timeout: 0.5)
    t.receive(nil, ::OFlow::Box.new([1,2,3]))
    assert_equal(1, t.history.size, 'one entry should be in the history')

    assert_equal("Array", t.history[0].box.contents.class.name, 'should have an Array in shipment')
    assert_equal("Exception", t.history[0].box.contents[0].class.name, 'should have an error in shipment')
  end

end

