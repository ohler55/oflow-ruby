
$VERBOSE = true

[ File.dirname(__FILE__),
  File.join(File.dirname(__FILE__), "../lib"),
  File.join(File.dirname(__FILE__), "../../oj/ext"),
  File.join(File.dirname(__FILE__), "../../oj/lib"),
  File.join(File.dirname(__FILE__), "../../ox/ext"),
  File.join(File.dirname(__FILE__), "../../ox/lib"),
  File.join(File.dirname(__FILE__), "../../oterm/lib"),
].each { |path| $: << path unless $:.include?(path) }

require 'minitest'
require 'minitest/unit'
require 'minitest/autorun'
