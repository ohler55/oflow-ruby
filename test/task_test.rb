#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

class Gather < ::OFlow::Actor
  attr_accessor :requests

  def initialize(task)
    super
    @requests = {}
  end

  def perform(task, op, box)
    if @requests[op].nil?
      @requests[op] = [box]
    else
      @requests[op] << box
    end
  end

end # Gather


class TaskTest < ::Test::Unit::TestCase

  def test_task_queue_count
    task = ::OFlow::Task.new(nil, 'test', Gather)
    assert_equal(0, task.queue_count())
    task.stop()
    task.receive(:dance, ::OFlow::Box.new('two step'))
    assert_equal(1, task.queue_count())
    task.receive(:dance, ::OFlow::Box.new('twist'))
    assert_equal(2, task.queue_count())
    task.close()
  end

  def test_task_perform
    task = ::OFlow::Task.new(nil, 'test', Gather)
    task.receive(:dance, ::OFlow::Box.new('two step'))
    sleep(0.5) # minimize dependencies for simplest possible test

    requests = task.actor.requests
    assert_equal(1, task.actor.requests.size)
    boxes = task.actor.requests[:dance]
    assert_equal(1, boxes.size)
    box = boxes[0]
    assert_equal(false, box.nil?)
    assert_equal('two step', box.contents)
    task.close()
  end

  def test_task_raise_after_close
    task = ::OFlow::Task.new(nil, 'test', Gather)
    task.close()
    assert_raise(ThreadError) { task.start() }
  end

=begin
  def test_opee_actor_order
    a = ::Relay.new()
    a.stop()
    a.on_idle(:relay, 17)
    a.priority_ask(:relay, 3)
    a.ask(:relay, 7)
    a.step()
    assert_equal(3, a.last_data)
    a.step()
    assert_equal(7, a.last_data)
    a.step()
    assert_equal(17, a.last_data)
    a.close()
  end

  def test_opee_actor_max_queue_count
    a = ::Relay.new(:max_queue_count => 4, :ask_timeout => 1.0)
    10.times { |i| a.ask(:slow, 0.1) }
    ::Opee::Env.wait_close()
    assert(4 > a.last_data.max)
  end
=end
end # TaskTest
