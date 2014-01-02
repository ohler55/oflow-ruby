#!/usr/bin/env ruby
# encoding: UTF-8

# Ubuntu does not accept arguments to ruby when called using env. To get warnings to show up the -w options is
# required. That can be set in the RUBYOPT environment variable.
# export RUBYOPT=-w

$VERBOSE = true

$: << File.join(File.dirname(__FILE__), "../lib")

require 'test/unit'
require 'oflow'

class BoxTest < ::Test::Unit::TestCase

  def test_box_new
    data = { a: [1, 'first'], b: true }
    j = ::OFlow::Box.new(data)

    assert_equal(data, j.contents, 'data should be the same as pass in')
    
    assert_equal(true, j.contents.frozen?, 'contents should be frozen')
    assert_equal(true, j.contents[:a].frozen?, 'members of contents should be frozen')
    assert_equal(true, j.contents[:a][1].frozen?, 'members of contentes should be frozen all the way down')
  end

  def test_box_dup
  end

  def test_box_spawn
  end

  def test_box_thaw
  end

  def test_box_freeze
  end

  # TBD tests for get in hash, array and single value
  def test_box_get
  end

  # TBD tests for get in hash, array and single value
  def test_box_set
  end

end # BoxTest
