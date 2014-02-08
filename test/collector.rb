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
    @contents_only = options.fetch(:contents_only, true)
  end

  def perform(op, box)
    if @contents_only
      @collection << box.contents
    else
      @collection << box
    end
  end

end # Collector

