Railgun
=======

Railgun is a Ruby client for a _nailgun_ server. What is _nailgun_ and why
should you care?

nailgun
-------

Invoking Java command line utilities is costly. Most (and often, all) of the
cost comes from spinning up a JVM for each invocation. _nailgun_
(http://github.com/martylamb/nailgun) is a clever approach to resolve this
issue. The idea is to keep a JVM running with all of the required classes loaded
and use a thin client to execute arbitrary commands. Please see the _nailgun_
project for more information.

Why Railgun
-----------

While the C client that the _nailgun_ project provides is great, it is still not
easy to integrate it with existing Ruby applications. The goal of Railgun is to
give developers a library that can be used to execute arbitrary code on the
_nailgun_ server and avoid invoking an external process or parsing the output
from _stdout_ or _stderr_ of that process.

Missing features
----------------

I hope this section gets smaller over time, but currently the following
functionality (that is present in the C _nailgun_ client is missing:

* Interactive sessions
  Railgun essentially ignores the information from the server that it is ready
  to accept input and does not allow for an interactive usage.
* Passing a file to the remote server (_--nailgun-filearg_)
  I think this is akin to doing something like: 

  ```
  awesome_command < foo
  ```

  and allows for the file _foo_ to be passed in. That is not currently implemented
  with Railgun.


Installing
----------

The software is very much in the alpha stage and should be treated as such. The
code is straightforward, but there may be bugs. To set it up:

1. Clone the github repository

2. Build the gem:
   ```
   gem build railgun.gemspec
   ```

3. Install the gem
   ```
   gem install railgun-0.0.1.gem
   ```

Lastly, the code does use Ruby 1.9 syntax and will *not* function on Ruby 1.8.
Please use Ruby >= 1.9

Usage
-----

Here is a short example of using Railgun. It assumes we have started the
_nailgun_ server with the _com.example.HelloWorld_ class available and that
class implements a _main()_ method that will print out _Hello World_.

```ruby
require 'railgun'

client = Railgun::Client.new

client.connect
result = client.execute('com.example.HelloWorld.Main')
client.close

puts result.out
puts result.err
puts result.exitcode
```

We can also supply arguments to the command. Imagine the _main_ method accepts a
string specifying the string to output. To do that, we can modify the code as
follows:
```ruby
require 'railgun'

client = Railgun::Client.new

client.connect
args = %w{ --string Goodbye }
result = client.execute('com.example.HelloWorld.Main', args: args)
client.close

puts result.out
puts result.err
puts result.exitcode
```

Lastly, the _nailgun_ server expects 1 session per socket. That means you should
instantiate a new _Railgun::Client_ object for each new thread and avoid using a
single _Railgun::Client_ object across multiple threads.
