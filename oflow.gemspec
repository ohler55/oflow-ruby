
require 'date'
require File.join(File.dirname(__FILE__), 'lib/oflow/version')

Gem::Specification.new do |s|
  s.name = 'oflow'
  s.version = ::OFlow::VERSION
  s.authors = "Peter Ohler"
  s.date = Date.today.to_s
  s.email = "peter@ohler.com"
  s.homepage = "http://www.ohler.com/oflow"
  s.summary = 'Operations Workflow in Ruby'
  s.description = %|Operations Workflow in Ruby. This implements a workflow/process flow using multiple task nodes that each have their own queues and execution thread.|
  s.licenses = ['MIT']

  s.files = Dir["{lib,test}/**/*.rb"] + ['LICENSE', 'README.md']

  s.require_paths = ['lib']

  s.extra_rdoc_files = ['README.md']
  s.rdoc_options = ['--main', 'README.md']
  
  s.rubyforge_project = 'oflow'
end
