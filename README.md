OFlow-ruby
==========

Operations Workflow in Ruby. This implements a workflow/process flow using
multiple task nodes that each have their own queues and execution thread.

## Installation
    gem install oflow

## Documentation

*Documentation*: http://www.ohler.com/oflow

## Source

*GitHub* *repo*: https://github.com/ohler55/oflow

*RubyGems* *repo*: https://rubygems.org/gems/oflow

Follow [@peterohler on Twitter](http://twitter.com/#!/peterohler) for announcements and news about the OFlow gem.

## Build Status

[![Build Status](https://travis-ci.org/ohler55/oflow-ruby.png?branch=master)](https://travis-ci.org/ohler55/oflow-ruby)

## Release Notes

### Current Release 0.7

 - Simplified the APIs and structure.

 - Added OmniGraffle support. Diagrams can now be executed.

### Release 0.6

 - Added HTTP Server Actor that acts as a simple HTTP server.

### Release 0.5

 - Added Persister Actor that acts as a simple local store database.

### Release 0.4

 - Added support for dynamic Timer options updates.

 - Added Balancer Actor for load balancing of processing across multiple tasks.

 - Added Merger Actor that merges two or more processing paths.

### Release 0.3

 - Initial release with minimal features.

## Description

Workflow or more accurately, process flow is associated with processing data
based on a diagram of what the processing steps are. OFlow-Ruby implements that
in Ruby. Each node in a flow diagram is processing unit with it's own
thread. This allows highly parallel processing of data or at least as much as
Ruby allows. The future C version will exploit parallel processing to a greater
extent with much higher performance.

One of the problem in any system that processes data in parallel is determing
what is going on in the system. OFlow provides a run time inspector that can
monitor and control the system and individual nodes in a flow.

## How to Use / Example

Flows are composed of individual building blocks referred to as Tasks. A Task
wraps an Actor that is the custom portion of a Task. Once the individual Actors
have been written they are assembled by linking Tasks together to define the
process flow. The process flow can be defined in Ruby or in the near future with
a drawing application such as OmniGraffle.

The approach of using diagrams to define what is effectively a program allows
less experience developers to assmeble pieces build by more experienced
developers. It also make is much easier to describe a process to non-developers.

OFlow uses a design pattern of queues and encapsulated processing units in the
form of Tasks. It also forces isolation by freezing data that is passed from one
Task to another to assure data that is sent to more than one Task is not
modified by another Task.

Putting it all together in a simple hello world flow with timmer triggers starts
with defining a hello world Actor in a file called helloworld.rb.

```ruby
require 'oflow'

class HelloWorld < ::OFlow::Actor
  def initialize(task, options)
    super
  end

  def perform(op, box)
    puts 'Hello World!'
  end
end
```

Next build the flow using Ruby code.

```ruby
env = ::OFlow::Env.new('')

def hello_flow(period)
  env.flow('hello_world') { |f|
    f.task(:repeater, ::OFlow::Actors::Timer, repeat: 3, period: period) { |t|
      t.link(nil, :hello, nil)
    }
    f.task(:hello, HelloWorld)
  }
  env.prepare()
  env.start()
end

hello_flow(1.0)

if $0 == __FILE__
  env.flush()
end
```

Running the helloworld.rb results in this output.

```
> helloworld.rb
Hello World!
Hello World!
Hello World!
>
```

## Future Features

 - .svg file input for configuration.

 - Visio file input for configuration.

 - CallOut Actor that uses pipes and fork to use a non-Ruby actor.

 - Cross linking Tasks and Flows.

 - Dynamic links to Tasks and Flows.

 - High performance C version. Proof of concept puts the performance range at
   around 10M operations per second where an operation is one task execution per
   thread.

 - HTTP/Websockets based inpector.

# Links

## Links of Interest

*Fast XML parser and marshaller on RubyGems*: https://rubygems.org/gems/ox

*Fast XML parser and marshaller on GitHub*: https://github.com/ohler55/ox

[Oj Object Encoding Format](http://www.ohler.com/dev/oj_misc/encoding_format.html) describes the OJ Object JSON encoding format.

[Need for Speed](http://www.ohler.com/dev/need_for_speed/need_for_speed.html) for an overview of how Oj::Doc was designed.

[Oj Strict Mode Performance](http://www.ohler.com/dev/oj_misc/performance_strict.html) compares Oj strict mode parser performance to other JSON parsers.

[Oj Compat Mode Performance](http://www.ohler.com/dev/oj_misc/performance_compat.html) compares Oj compat mode parser performance to other JSON parsers.

[Oj Object Mode Performance](http://www.ohler.com/dev/oj_misc/performance_object.html) compares Oj object mode parser performance to other marshallers.

[Oj Callback Performance](http://www.ohler.com/dev/oj_misc/performance_callback.html) compares Oj callback parser performance to other JSON parsers.
