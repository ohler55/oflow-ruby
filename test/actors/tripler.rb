#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(File.dirname(__FILE__)) unless $:.include? File.dirname(File.dirname(__FILE__))

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../../lib"),
  File.join(File.dirname(__FILE__), "../../../oj/ext"),
  File.join(File.dirname(__FILE__), "../../../oj/lib"),
].each { |path| $: << path unless $:.include?(path) }

require 'oj'

Oj.load(STDIN, mode: :compat) do |input|
  ctx = input["ctx"]
  a = input["in"]
  a.map! { |v| v * 3 }
  out = { "ctx" => ctx, "out" => a }
  puts Oj.dump(out, mode: :compat, indent: 0)
  STDOUT.flush
end
