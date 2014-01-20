#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }

require 'oflow'

class Collector < ::OFlow::Actor
  attr_accessor :collection

  def initialize(task, options)
    super
    @collection = []
  end

  def perform(task, op, box)
    @collection << box.contents
  end

end # Collector

