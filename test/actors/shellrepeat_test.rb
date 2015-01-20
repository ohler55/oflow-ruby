#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

require 'helper'
require 'oflow'
require 'oflow/test'

class ShellRepeatTest < ::MiniTest::Test

  def test_shellone_config
    root_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::ShellRepeat, state: ::OFlow::Task::BLOCKED,
                                     dir: 'somewhere',
                                     cmd: 'pwd',
                                     timeout: 0.5)
    assert_equal(File.join(root_dir, 'somewhere'), t.actor.dir, 'dir set from options')
    assert_equal('pwd', t.actor.cmd, 'cmd set from options')
    assert_equal(0.5, t.actor.timeout, 'timeout set from options')
  end

end

