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

[![Build Status](https://secure.travis-ci.org/ohler55/oflow.png?branch=master)](http://travis-ci.org/ohler55/oflow)

### Current Release 0.3

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

  def perform(task, op, box)
    puts 'Hello World!'
  end
end
```

Next build the flow using Ruby code.

```ruby
def hello_flow(period)
    ::OFlow::Env.flow('hello_world') { |f|
      f.task(:repeater, ::OFlow::Actors::Timer, repeat: 3, period: period) { |t|
        t.link(nil, :hello, nil)
      }
      f.task(:hello, HelloWorld)
    }
end

hello_flow(1.0)

if $0 == __FILE__
  ::OFlow::Env.flush()
end
```

Running the helloworld.rb results in this output.

```
> helloworld.rb
Hello World!
Hello World!
Hello World!
Hello World!
>
```

## Future Features

 - Balancer Actor that distributes to a set of others Tasks based on how busy each is.

 - Merger Actor that waits for a criteria to be met before continuing.

 - HTTP Server Actor

 - Persister Actor (write to disk and ready on start)

 - CallOut Actor that uses pipes and fork to use a non-Ruby actor.

 - Cross linking Tasks and Flows.

 - Dynamic links to Tasks and Flows.

 - OmniGraffle file input for configuration.

 - .svg file input for configuration.

 - Visio file input for configuration.

 - High performance C version. Proof of concept puts the performance range at
   around 10M operations per second where an operation is one task execution per
   thread.

 - HTTP based inpector.

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

### License:

    Copyright (c) 2014, Peter Ohler
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
     - Redistributions of source code must retain the above copyright notice, this
       list of conditions and the following disclaimer.
    
     - Redistributions in binary form must reproduce the above copyright notice,
       this list of conditions and the following disclaimer in the documentation
       and/or other materials provided with the distribution.
    
     - Neither the name of Peter Ohler nor the names of its contributors may be
       used to endorse or promote products derived from this software without
       specific prior written permission.
    
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
