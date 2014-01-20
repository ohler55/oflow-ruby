#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }


require 'test/unit'

require 'flow_basic_test'
require 'flow_rescue_test'
require 'flow_log_test'
