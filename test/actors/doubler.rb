#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "../../../oj/ext"),
  File.join(File.dirname(__FILE__), "../../../oj/lib"),
].each { |path| $: << path unless $:.include?(path) }

require 'oj'

input = Oj.load(STDIN, mode: :compat)
input.map! { |v| v * 2 }
puts Oj.dump(input, mode: :compat, indent: 0)
