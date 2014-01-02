#!/usr/bin/env ruby
# encoding: UTF-8

# Ubuntu does not accept arguments to ruby when called using env. To get warnings to show up the -w options is
# required. That can be set in the RUBYOPT environment variable.
# export RUBYOPT=-w

$VERBOSE = true

$: << File.join(File.dirname(__FILE__), "../lib")

require 'test/unit'
require 'oflow'

class TrackerTest < ::Test::Unit::TestCase

  def test_tracker_new
    t = ::OFlow::Tracker.new('here')
    t2 = ::OFlow::Tracker.new('here')

    assert_not_equal(t.id, t2.id, 'id must be unique')
    assert_equal('here', t.track[0].location)
  end

  def test_tracker_track
    t = ::OFlow::Tracker.new('here')
    t2 = t.receive('there')

    assert_equal('here', t.track[0].location)
    assert_equal('here', t2.track[0].location)
    assert_equal('there', t2.track[1].location)
  end

  def test_tracker_merge
    t = ::OFlow::Tracker.new('here')
    # 2 different paths
    t2 = t.receive('there')
    t3 = t.receive('everywhere')
    # should not happen but should handle merging when not back to a common place
    t4 = t2.merge(t3)
    assert_equal('here', t4.track[0].location)
    assert_equal(true, t4.track[1].is_a?(Array))
    assert_equal(2, t4.track[1].size)
    assert_equal('there', t4.track[1][0][0].location)
    assert_equal('everywhere', t4.track[1][1][0].location)

    # back to a common location
    t2 = t2.receive('home')
    t3 = t3.receive('home')
    t4 = t2.merge(t3)
    assert_equal('here', t4.track[0].location)
    assert_equal(true, t4.track[1].is_a?(Array))
    assert_equal(2, t4.track[1].size)
    assert_equal('there', t4.track[1][0][0].location)
    assert_equal('everywhere', t4.track[1][1][0].location)
    assert_equal('home', t4.track[2].location)
  end

end # TrackerTest
