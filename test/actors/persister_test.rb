#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "..")
].each { |path| $: << path unless $:.include?(path) }

require 'test/unit'
require 'oflow'
require 'oflow/test'

class PersisterTest < ::Test::Unit::TestCase

  def test_persister_config
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     dir: 'db/something',
                                     key_path: 'key',
                                     cache: false,
                                     single_file: true,
                                     with_tracker: true,
                                     with_seq_num: true,
                                     historic: true,
                                     seq_path: 'seq')
    assert_equal('db/something', t.actor.dir, 'dir set from options')
    assert_equal('key', t.actor.key_path, 'key_path set from options')
    assert_equal('seq', t.actor.seq_path, 'seq_path set from options')
    assert_equal(false, t.actor.caching?, 'cache set from options')
    assert_equal(true, t.actor.single_file, 'single_file set from options')
    assert_equal(true, t.actor.historic, 'historic set from options')
    assert(Dir.exist?(t.actor.dir), 'dir exists')
    `rm -r #{t.actor.dir}`

    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED)
    assert_equal('db/test/persist', t.actor.dir, 'dir set from options')
    assert_equal('key', t.actor.key_path, 'key_path set from options')
    assert_equal('seq', t.actor.seq_path, 'seq_path set from options')
    assert_equal(true, t.actor.caching?, 'cache set from options')
    assert_equal(false, t.actor.single_file, 'single_file set from options')
    assert_equal(false, t.actor.historic, 'historic set from options')
    assert(Dir.exist?(t.actor.dir), 'dir exists')
    `rm -r #{t.actor.dir}`
  end

  def test_persister_historic
    `rm -rf db/test/persist`
    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     historic: true)
    # insert
    t.receive(:insert, ::OFlow::Box.new({dest: :here, key: 'one', data: 0}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:here, t.history[0].dest, 'should have shipped to :here')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')
    t.reset()

    # read
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:read, t.history[0].dest, 'should have shipped to :read')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # update
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 1, data: 1}))
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 2, data: 2}))

    # TBD verify file exist and link point to correct place
    # TBD load and compare

    # TBD delete

    puts "*** result: #{t.history}"

    # TBD clear and verify dir is empty

    #`rm -r #{t.actor.dir}`
  end

  # TBD test non-historic

  # TBD test query

  # TBD read non-existant record
  
end
