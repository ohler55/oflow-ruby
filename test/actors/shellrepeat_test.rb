#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

require 'helper'
require 'oflow'
require 'oflow/test'

class ShellRepeatTest < ::MiniTest::Test

  def test_shellrepeat_config
    root_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::ShellRepeat, state: ::OFlow::Task::BLOCKED,
                                     dir: 'somewhere',
                                     cmd: 'tripler.rb',
                                     timeout: 0.5)
    assert_equal(File.join(root_dir, 'somewhere'), t.actor.dir, 'dir set from options')
    assert_equal('tripler.rb', t.actor.cmd, 'cmd set from options')
    assert_equal(0.5, t.actor.timeout, 'timeout set from options')
  end

  def test_shellrepeat_simple
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::ShellRepeat, state: ::OFlow::Task::BLOCKED,
                                     dir: 'actors',
                                     cmd: './tripler.rb',
                                     timeout: 0.5)
    t.receive(nil, ::OFlow::Box.new([1,2,3]))
    t.join(1.0)
    assert_equal(1, t.history.size, 'one entry should be in the history')

    assert_equal([3,6,9], t.history[0].box.contents, 'should  have correct contents in shipment')
    t.receive(nil, ::OFlow::Box.new([3,2,1]))
    t.join(1.0)
    assert_equal(2, t.history.size, 'two entries should be in the history')
    # optional
    t.receive(:kill, ::OFlow::Box.new([1,2,3]))
    t.join(1.0)
  end

end

