#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__))

require 'helper'
require 'oflow'
require 'oflow/test'

class PersisterTest < ::MiniTest::Test

  def test_persister_config
    t = ::OFlow::Test::ActorWrap.new('test', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     dir: 'db/something',
                                     key_path: 'key',
                                     cache: false,
                                     data_path: 'data',
                                     with_tracker: true,
                                     with_seq_num: true,
                                     historic: true,
                                     seq_path: 'seq')
    assert_equal('db/something', t.actor.dir, 'dir set from options')
    assert_equal('key', t.actor.key_path, 'key_path set from options')
    assert_equal('seq', t.actor.seq_path, 'seq_path set from options')
    assert_equal('data', t.actor.data_path, 'data_path set from options')
    assert_equal(false, t.actor.caching?, 'cache set from options')
    assert_equal(true, t.actor.historic, 'historic set from options')
    assert(Dir.exist?(t.actor.dir), 'dir exists')
    `rm -r #{t.actor.dir}`

    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED)
    assert_equal('db/test/persist', t.actor.dir, 'dir set from options')
    assert_equal('key', t.actor.key_path, 'key_path set from options')
    assert_equal('seq', t.actor.seq_path, 'seq_path set from options')
    assert_equal(true, t.actor.caching?, 'cache set from options')
    assert_equal(nil, t.actor.data_path, 'data_path set from options')
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

    # read
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:read, t.history[0].dest, 'should have shipped to :read')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # update
    t.reset()
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 1, data: 1}))
    # no seq so try to find max
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', data: 2}))
    assert_equal(2, t.history.size, 'one entry for each update expected')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(3, files.size, 'should be 3 history historic files')
    # make sure current object is last one saved
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal({:dest=>:here, :key=>'one', :data=>2, :seq=>3},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # delete
    t.reset()
    t.receive(:delete, ::OFlow::Box.new({dest: :deleted, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:deleted, t.history[0].dest, 'should have shipped to :read')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(3, files.size, 'should be 3 history historic files')
    # make sure object was deleted
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')

    # query
    10.times do |i|
      t.receive(:insert, ::OFlow::Box.new({dest: :here, key: "rec-#{i}", data: i}))
    end
    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: nil}))
    assert_equal(10, t.history[0].box.contents.size, 'query with nil returns all')

    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: Proc.new{|rec,key,seq| 4 < rec[:data] }}))
    assert_equal(5, t.history[0].box.contents.size, 'query return check')

    # clear
    t.reset()
    t.receive(:clear, ::OFlow::Box.new({dest: :cleared}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    files = Dir.glob(File.join(t.actor.dir, '**/*.json'))
    assert_equal(0, files.size, 'should be no files')
  end

  def test_persister_historic_cached
    `rm -rf db/test/persist`
    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     historic: true,
                                     cache: true)
    assert(t.actor.caching?, 'verify caching is on')

    # insert
    t.receive(:insert, ::OFlow::Box.new({dest: :here, key: 'one', data: 0}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:here, t.history[0].dest, 'should have shipped to :here')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'insert record contents')

    # read
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:read, t.history[0].dest, 'should have shipped to :read')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # update
    t.reset()
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 1, data: 1}))
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 2, data: 2}))
    assert_equal(2, t.history.size, 'one entry for each update expected')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(3, files.size, 'should be 3 history historic files')
    # make sure current object is last one saved
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal({:dest=>:here, :key=>'one', :data=>2, :seq=>3},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # delete
    t.reset()
    t.receive(:delete, ::OFlow::Box.new({dest: :deleted, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:deleted, t.history[0].dest, 'should have shipped to :read')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(3, files.size, 'should be 3 history historic files')
    # make sure object was deleted
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')

    # query
    10.times do |i|
      t.receive(:insert, ::OFlow::Box.new({dest: :here, key: "rec-#{i}", data: i}))
    end
    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: nil}))
    assert_equal(10, t.history[0].box.contents.size, 'query with nil returns all')

    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: Proc.new{|rec,key,seq| 4 < rec[:data] }}))
    assert_equal(5, t.history[0].box.contents.size, 'query return check')

    # clear
    t.reset()
    t.receive(:clear, ::OFlow::Box.new({dest: :cleared}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    files = Dir.glob(File.join(t.actor.dir, '**/*.json'))
    assert_equal(0, files.size, 'should be no files')
  end

  def test_persister_not_historic
    `rm -rf db/test/persist`
    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     historic: false)
    # insert
    t.receive(:insert, ::OFlow::Box.new({dest: :here, key: 'one', data: 0}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:here, t.history[0].dest, 'should have shipped to :here')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # read
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:read, t.history[0].dest, 'should have shipped to :read')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # update
    t.reset()
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 1, data: 1}))
    # no seq so try to find max
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', data: 2}))
    assert_equal(2, t.history.size, 'one entry for each update expected')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(1, files.size, 'should be just one file')
    # make sure current object is last one saved
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal({:dest=>:here, :key=>'one', :data=>2, :seq=>3},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # delete
    t.reset()
    t.receive(:delete, ::OFlow::Box.new({dest: :deleted, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:deleted, t.history[0].dest, 'should have shipped to :read')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(0, files.size, 'should no historic files')
    # make sure object was deleted
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')

    # query
    10.times do |i|
      t.receive(:insert, ::OFlow::Box.new({dest: :here, key: "rec-#{i}", data: i}))
    end
    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: nil}))
    assert_equal(10, t.history[0].box.contents.size, 'query with nil returns all')

    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: Proc.new{|rec,key,seq| 4 < rec[:data] }}))
    assert_equal(5, t.history[0].box.contents.size, 'query return check')

    # clear
    t.reset()
    t.receive(:clear, ::OFlow::Box.new({dest: :cleared}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    files = Dir.glob(File.join(t.actor.dir, '**/*.json'))
    assert_equal(0, files.size, 'should be no files')
  end

  def test_persister_not_historic_cached
    `rm -rf db/test/persist`
    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     historic: false,
                                     cache: true)
    # insert
    t.receive(:insert, ::OFlow::Box.new({dest: :here, key: 'one', data: 0}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:here, t.history[0].dest, 'should have shipped to :here')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # read
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:read, t.history[0].dest, 'should have shipped to :read')
    assert_equal({:dest=>:here, :key=>'one', :data=>0, :seq=>1},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # update
    t.reset()
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 1, data: 1}))
    # no seq so try to find max
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', data: 2}))
    assert_equal(2, t.history.size, 'one entry for each update expected')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(1, files.size, 'should be just one file')
    # make sure current object is last one saved
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal({:dest=>:here, :key=>'one', :data=>2, :seq=>3},
                 t.history[0].box.contents, 'should correct contents in shipment')

    # delete
    t.reset()
    t.receive(:delete, ::OFlow::Box.new({dest: :deleted, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:deleted, t.history[0].dest, 'should have shipped to :read')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(0, files.size, 'should no historic files')
    # make sure object was deleted
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')

    # query
    10.times do |i|
      t.receive(:insert, ::OFlow::Box.new({dest: :here, key: "rec-#{i}", data: i}))
    end
    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: nil}))
    assert_equal(10, t.history[0].box.contents.size, 'query with nil returns all')

    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: Proc.new{|rec,key,seq| 4 < rec[:data] }}))
    assert_equal(5, t.history[0].box.contents.size, 'query return check')

    # clear
    t.reset()
    t.receive(:clear, ::OFlow::Box.new({dest: :cleared}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    files = Dir.glob(File.join(t.actor.dir, '**/*.json'))
    assert_equal(0, files.size, 'should be no files')
  end

  def test_persister_data_path
    `rm -rf db/test/persist`
    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED,
                                     historic: false,
                                     cache: true,
                                     data_path: 'data')
    # insert
    t.receive(:insert, ::OFlow::Box.new({dest: :here, key: 'one', data: 0}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:here, t.history[0].dest, 'should have shipped to :here')
    assert_equal(0, t.history[0].box.contents, 'should correct contents in shipment')

    # read
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:read, t.history[0].dest, 'should have shipped to :read')
    assert_equal(0, t.history[0].box.contents, 'should correct contents in shipment')

    # update
    t.reset()
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', seq: 1, data: 1}))
    # no seq so try to find max
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'one', data: 2}))
    assert_equal(2, t.history.size, 'one entry for each update expected')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(1, files.size, 'should be just one file')
    # make sure current object is last one saved
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(2, t.history[0].box.contents, 'should correct contents in shipment')

    # delete
    t.reset()
    t.receive(:delete, ::OFlow::Box.new({dest: :deleted, key: 'one'}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(:deleted, t.history[0].dest, 'should have shipped to :read')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    # check for 3 files in the db
    files = Dir.glob(File.join(t.actor.dir, '**/*~[0123456789].json'))
    assert_equal(0, files.size, 'should no historic files')
    # make sure object was deleted
    t.reset()
    t.receive(:read, ::OFlow::Box.new({dest: :read, key: 'one'}))
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')

    # query
    10.times do |i|
      t.receive(:insert, ::OFlow::Box.new({dest: :here, key: "rec-#{i}", data: i}))
    end
    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: nil}))
    assert_equal(10, t.history[0].box.contents.size, 'query with nil returns all')

    t.reset()
    t.receive(:query, ::OFlow::Box.new({dest: :query, expr: Proc.new{|rec,key,seq| 4 < rec }}))
    assert_equal(5, t.history[0].box.contents.size, 'query return check')

    # clear
    t.reset()
    t.receive(:clear, ::OFlow::Box.new({dest: :cleared}))
    assert_equal(1, t.history.size, 'one entry should be in the history')
    assert_equal(nil, t.history[0].box.contents, 'should correct contents in shipment')
    files = Dir.glob(File.join(t.actor.dir, '**/*.json'))
    assert_equal(0, files.size, 'should be no files')
  end

  def test_persister_errors
    `rm -rf db/test/persist`
    t = ::OFlow::Test::ActorWrap.new('persist', ::OFlow::Actors::Persister, state: ::OFlow::Task::BLOCKED)

    # insert with no key
    t.receive(:insert, ::OFlow::Box.new({dest: :here, nokey: 'one', data: 0}))
    action = t.history[0]
    assert_equal(:error, action.dest, 'insert with no key destination')
    assert_equal(::OFlow::Actors::Persister::KeyError, action.box.contents[0].class, 'insert with key error')

    # update non-existant record
    t.reset()
    t.receive(:update, ::OFlow::Box.new({dest: :here, key: 'not-me', data: 0}))
    action = t.history[0]
    assert_equal(:error, action.dest, 'error destination')
    assert_equal(::OFlow::Actors::Persister::NotFoundError, action.box.contents[0].class, 'insert with not found error')
  end

end
