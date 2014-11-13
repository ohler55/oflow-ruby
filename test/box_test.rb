#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(__FILE__)

require 'helper'
require 'oflow'

class Access
  attr_accessor :x, :y
  def initialize(x, y)
    @x = x
    @y = y
  end
end # Access

class BoxTest < ::MiniTest::Test

  def test_box_new
    data = { a: [1, 'first'], b: true }
    t = ::OFlow::Tracker.create('test')
    box = ::OFlow::Box.new(data, t)

    assert_equal(data, box.contents, 'data should be the same as what was passed in')
    assert_equal(t, box.tracker, 'tracker should be the same as what was passed in')
  end

  def test_box_freeze
    data = { a: [1, 'first'], b: true }
    t = ::OFlow::Tracker.create('test')
    box = ::OFlow::Box.new(data, t).freeze()

    assert_equal(true, box.frozen?, 'box should be frozen')
    assert_equal(true, box.contents.frozen?, 'contents should be frozen')
    assert_equal(true, box.contents[:a].frozen?, 'members of contents should be frozen')
    assert_equal(true, box.contents[:a][1].frozen?, 'members of contentes should be frozen all the way down')
    assert_equal(true, box.tracker.frozen?, 'tracker should be frozen')
  end

  def test_box_thaw
    data = { a: [1, 'first'], b: true }
    t = ::OFlow::Tracker.create('test')
    box = ::OFlow::Box.new(data, t).freeze()
    # make sure it is frozen first.
    assert_equal(true, box.frozen?, 'box should be frozen')
    box = box.thaw()

    assert_equal(false, box.frozen?, 'box should not be frozen')
    assert_equal(false, box.contents.frozen?, 'contents not should be frozen')
    assert_equal(false, box.contents[:a].frozen?, 'members of contents should not be frozen')
    assert_equal(false, box.contents[:a][1].frozen?, 'members of contentes should not be frozen all the way down')
    assert_equal(true, box.tracker.frozen?, 'tracker should still be frozen')
  end

  def test_box_receive
    data = { a: [1, 'first'], b: true }
    t = ::OFlow::Tracker.create('test')
    box = ::OFlow::Box.new(data, t).freeze()
    # make sure it is frozen first.
    assert_equal(true, box.frozen?, 'box should be frozen')

    rbox = box.receive('here', 'try')
    assert_equal(false, rbox.frozen?, 'box should not be frozen')
    assert_equal(true, box.contents.frozen?, 'contents should be frozen')
    assert_equal(2, rbox.tracker.track.size, 'track should have 2 entries')
    assert_equal('test-', rbox.tracker.track[0].where, 'check track entry 0')
    assert_equal('here-try', rbox.tracker.track[1].where, 'check track entry 1')
  end

  def test_box_get
    data = { a: [1, 'first'], b: true, 'c' => 'see', d: Access.new([7, 3], :y) }
    box = ::OFlow::Box.new(data).freeze()
    # Hash access
    assert_equal(true, box.get('b'), 'get b')
    assert_equal('see', box.get('c'), 'get c')
    assert_equal(nil, box.get('x'), 'get x')
    # Array access
    assert_equal(1, box.get('a:0'), 'get a:0')
    assert_equal('first', box.get('a:1'), 'get a:1')
    assert_equal(nil, box.get('a:2'), 'get a:2')
    # nil path
    assert_equal(data, box.get(nil), 'get nil')
    assert_equal(data, box.get(''), 'get nil')
    # Object
    assert_equal([7, 3], box.get('d:x'), 'get d:x')
    assert_equal(7, box.get('d:x:0'), 'get d:x:0')
    assert_equal(:y, box.get('d:y'), 'get d:y')
    assert_equal(nil, box.get('d:z'), 'get d:z')
    # more bad paths
    assert_equal(nil, box.get('b:0'), 'get b:0')
  end

  def test_box_set
    data = { a: [1, 'first'], b: true, 'c' => 'see', d: Access.new([7, 3], :y) }
    box = ::OFlow::Box.new(data).freeze()

    b2 = box.set('b', false)
    assert_equal(false, b2.get('b'), 'get b')
    assert_equal(true, box.contents[:a].frozen?, 'other contents should be frozen')

    b2 = box.set('a:0', 3)
    assert_equal(3, b2.get('a:0'), 'get a:0')

    b2 = box.set('a:2', 5)
    assert_equal(5, b2.get('a:2'), 'get a:2')

    b2 = box.set('c', 'mite')
    assert_equal('mite', b2.get('c'), 'get c')

    b2 = box.set('e:ha', 'new')
    assert_equal('new', b2.get('e:ha'), 'get e:ha')

    b2 = box.set('f:1', 'new')
    assert_equal(Array, b2.get('f').class, 'get f class')
    assert_equal(nil, b2.get('f:0'), 'get f:0')
    assert_equal('new', b2.get('f:1'), 'get f:1')

    assert_raises(::OFlow::FrozenError) { box.set('d:x:1', 'three') }
  end

end # BoxTest
