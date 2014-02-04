#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'oflow'

class Stutter < ::OFlow::Actor
  
  def initialize(task, options)
    super
  end

  def perform(op, box)
    task.ship(:collector, ::OFlow::Box.new([task.full_name, op, box.contents]))
    task.ship(op, box)
  end

end # Stutter
