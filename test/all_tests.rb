#!/usr/bin/env ruby
# encoding: UTF-8

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib")
].each { |path| $: << path unless $:.include?(path) }


require 'test/unit'

require 'box_test'
require 'task_test'
require 'log_test'
require 'tracker_test'
require 'actorwrap_test'

require 'flow_basic_test'
require 'flow_rescue_test'
require 'flow_log_test'
require 'flow_cfg_error_test'
require 'flow_rescue_test'
require 'flow_nest_test'
require 'flow_tracker_test'

