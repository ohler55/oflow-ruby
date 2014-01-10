#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'

class Gather < ::OFlow::Actor
  attr_accessor :requests

  def initialize(task, options)
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
    task.shutdown()
  end

  def test_task_perform
    task = ::OFlow::Task.new(nil, 'test', Gather)
    task.receive(:dance, ::OFlow::Box.new('two step'))
    task.flush()

    requests = task.actor.requests
    assert_equal(1, task.actor.requests.size)
    boxes = task.actor.requests[:dance]
    assert_equal(1, boxes.size)
    box = boxes[0]
    assert_equal(false, box.nil?)
    assert_equal('two step', box.contents)
    task.shutdown()
  end

  def test_task_perform_shutdown
    task = ::OFlow::Task.new(nil, 'test', Gather)
    task.receive(:dance, ::OFlow::Box.new('two step'))
    task.shutdown(true)

    requests = task.actor.requests
    assert_equal(1, task.actor.requests.size)
    boxes = task.actor.requests[:dance]
    assert_equal(1, boxes.size)
    box = boxes[0]
    assert_equal(false, box.nil?)
    assert_equal('two step', box.contents)
  end

  def test_task_raise_after_close
    task = ::OFlow::Task.new(nil, 'test', Gather)
    task.shutdown()
    assert_raise(ThreadError) { task.start() }
  end

  def test_task_max_queue_count
    task = ::OFlow::Task.new(nil, 'test', Gather, :max_queue_count => 4, :req_timeout => 0.1)
    task.stop()
    6.times do |i|
      begin
        task.receive(:dance, ::OFlow::Box.new(i))
      rescue ::OFlow::BusyError => e
        # expected for all over first 4
      end
    end
    task.start()
    task.shutdown(true)

    requests = task.actor.requests
    boxes = task.actor.requests[:dance]
    assert_equal(4, boxes.size)
    nums = boxes.map { |box| box.contents }
    assert_equal([0, 1, 2, 3], nums)
  end

end # TaskTest
