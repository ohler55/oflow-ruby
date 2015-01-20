#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "../../../oj/ext"),
  File.join(File.dirname(__FILE__), "../../../oj/lib"),
].each { |path| $: << path unless $:.include?(path) }

#input = gets()

#puts "*** input: #{input}"
puts "*** #{`pwd`}"
