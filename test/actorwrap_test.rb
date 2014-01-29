#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'
require 'oflow/test'

class Nonsense < ::OFlow::Actor
  def initialize(task, options)
    super
    @cnt = 0
  end

  def perform(task, op, box)
    @cnt += 1
    task.ship(:start, ::OFlow::Box.new(@cnt))
    task.ship(op, box)
    task.info("finished #{@cnt}")
  end

end # Nonsense

class ActorWrapTest < ::Test::Unit::TestCase

  def test_actorwrap
    wrap = ::OFlow::Test::ActorWrap.new('wrapper', Nonsense)

    wrap.receive(:first, ::OFlow::Box.new('word'))
    history = wrap.history.map { |action| action.to_s }
    assert_equal(['start: 1', 'first: word', 'log: [:info, "finished 1", ":test:wrapper"]'], history)

    wrap.receive(:second, ::OFlow::Box.new('This is a sentence.'))
    history = wrap.history.map { |action| action.to_s }
    assert_equal(['start: 1', 'first: word', 'log: [:info, "finished 1", ":test:wrapper"]',
                 'start: 2', 'second: This is a sentence.', 'log: [:info, "finished 2", ":test:wrapper"]'], history)

    wrap.reset()
    assert_equal([], wrap.history)
    wrap.receive(:third, ::OFlow::Box.new('word'))
    history = wrap.history.map { |action| action.to_s }
    assert_equal(['start: 3', 'third: word', 'log: [:info, "finished 3", ":test:wrapper"]'], history)
  end

end # ActorWrapTest
