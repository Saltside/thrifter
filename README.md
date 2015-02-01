# Thrifter

Thrifter addresses the shortcoming in the official library for
production uses. It's most important features are:

* Thread safe via connection pool
* Safe for use in long running processes
* Simple RPC queuing
* Retry support
* Proper timeout's by default
* Metrics
* Better handling
* Middleware

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'thrifter'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install thrifter

## Usage

`Thrifer` is a factory (similar to `DelegateClass`) for building
client classes. It can be used like `DelegateClass` or like `Struct`.
The result is subclasses of `Thrifter::Client`. The classes use the
same methods to make RPCs. For example if the thrift service has a
`fooBar` RPC, the generated class has a `fooBar` method to invoke the
RPC. Here are some examples.

```ruby
# Struct style
ServiceClient = Thrifter.build(MyService::Client)

The struct style take a block as well
ServiceClient = Thrifer.build(MyService::Client) do
  def custom_method(args)
    # something something
  end
end

# Delegate class style (easiest to add abstractions)
class MyServiceClient < Thrifter.build(MyService::Client)
  def custom_method(args)
    # something something
  end
end
```

### Configuration

`Thrifter` uses a configuration object on each class to track
dependent objects. Configured objects are injected into each instance.
This makes it easy to configure classes in different environment (e.g.
production vs test). All settings are documented below. `uri` is the
most important! It must be set to instantiate clients.

```ruby
class MyClient < Thrifer.build(MyService::Client)
  # Thrift specific things
  config.transport = Thrift::FramedTransport
  config.protocol = Thrift::BinaryTransport

  # Pool settings
  config.pool_size = 12
  config.pool_timeout = 0.15

  # Network Settings
  config.rpc_timeout = 0.15

  # Required to instantiate the client!
  config.uri = 'tcp://foo:2383'
end

#The common block form is supported as well
MyClient.configure do |config|
  # ... same as above
end
```

### RPC Metrics with Statsd

Statsd metrics are **opt-in**. By default, `Thrifter` sets the statsd
client to a null implementation. If you want metrics, set
`config.statsd` to an object that implements the [statsd-ruby][]
interface. `Thrifter` emits the following metrics:

* time on each rpc calls
* number of `Thrift::TransportException`
* number of `Thrift::ProtocolExeption`
* number of `Thrift::ApplicationExeption`
* number of `Timeout::Error`
* number of generic errors (e.g. none of the above known errors)

It's recommended that the `statsd` object do namespacing
(statsd-ruby has it built in). This ensures client metrics don't
get intermingled with wider application metrics. Here's an example:

```ruby
ServiceClient = Thrifter.build(MyService::Client)
# Now in production.rb
ServiceClient.config.statsd = Statsd.new namespace: 'my_service'
```

### RPC Queuing

Certain systems may need to queue RPCs to other systems. This is only
useful for `void` RPCs or for when an outside system may be flaky.
Assume `MyService` has a `logStats` RPC. Your application is producing
stats that should make it upstream, but there are intermitent network
problems effeciting stats collection. Include `Thrift::Queueing` and
any RPC will automatically be sent to sidekiq for eventual processing.

```ruby
class ServiceClient < Thrifter.build(MyService::Client)
  include Thrifter::Queuing
end
```

Now instances of `ServiceClient` now respond to `queued`. This returns
a queue based instance. All RPC methods will work as usual. Here's an
example:

```ruby
# Assume client is an instance of ServiceClient
my_service.queued.logStats({ 'users' => 5 })

# Naturally the block form may be used as well
my_service.queued do |queue|
  queue.logStats({ 'sessions' => 50 })
  queue.logStats({ 'posts' => 30 })
end
```

All RPCs will be sent to the `thrift` sidekiq queue. They will follow
default sidekiq retry backoff and the like.

### RPC Retrying

Systems have syncrhonous RPCs. Unfortunately sometimes these don't
work for whatever reason. It's good practice to retry these RPCs
(within certain limits) if they don't succeed the first time.
`Thrift::Retriable` is perfect for this use case.

```ruby
class ServiceClient < Thrifter.build(MyService::Client)
  include Thrifter::Retriable
end
```

```ruby
# Assume client is an instance of ServiceClient

# logStats will be retried 3 times at 0.1 second intervals if any
# known thrift or network errors happen.
my_service.retriable.logStats({ 'users' => 5 })

# These settings can be customized by the retriable method.
my_sevice.retriable({tries: 10, delay: 0.3 }).logStats({ 'sessions' => 50 })

# Naturally the block form may be used as well
my_service.retriable do |with_retry|
  with_retry.logStats({ 'sessions' => 50 })
  with_retry.logStats({ 'posts' => 30 })
end
```

`Thrift::Retriable` is a simple retry solution for syncronous RPCs.
Look into something like [retriable][] if you want a more robust
solution for different use cases.

### Middleware

The middleware approach is great for providing a flexible extension
points to hook into the RPC process. `Thrifter::Client` provides a
middleware implementation to common to many other ruby libraries.
Middleware can only be customized at the class level. This ensures
middleware applies when used in extensions.

```ruby
class MyClient < Thrifter.build(MyService::Client)
  use MyMiddlware
  use MySecondMiddleware
end
```

Since middleware must defined at the class level, you should defer
setting up middleware that depend on objects until process boot. For
example, if you have `LoggingMiddleware` and you need to log to
different places depending on environment, you should add the
middleware in whatever code configurres that environment. Only static
middleware should be configured directly in the class itself.

A middleware must implement the `call` method and accept at least one
argument to `initialize`. The `call` method recieves a `Thrifer::RPC`.
`Thrifter::RPC` is a sipmle struct with a `name` and `args` methods.
Here's an example:

```ruby
class LoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(rpc)
    puts "Running #{rp.name} with #{rpc.args.inspect}"
	@app.call rpc
  end
end
```

### Error Wrapping

A lot of things can go wrong in the thrift stack. This means the
caller may need to deal with a large amount of different exceptions.
For example, does it really matter if `Thrift::ProtocolException` or
`Thrift::TransportException` was raied? Can the caller recover from
either of them? No. So instead of allowing these semantics to
propogate up abstraction levels, it's better to encapsulate them in a
single error. This is easily implemented with a middleware and once is
included in the library. When this middleare is used, all known
networking & thrift exceptions will be raised as
`Thrifter::ClientError`.

```ruby
class MyService < Thrifter.build(MyService::Client)
  use Thrifter::ErrorWrapping
end
```

A list of other known error classes can be provided to wrap more than
the library's known set.

```ruby
class MyService < Thrifter.build(MyService::Client)
  use Thrifter::ErrorWrapping, [ SomeErrorClass ]
end
```

Note, `Thrifter` will still count individual errors as described the metrics
section.

### Pinging

Components in a system may need to inquire if other systems are
available before continuing. `Thrifer::Ping` is just that.
`Thrifter::Ping` assumes the service has a `ping` RPC. If your
service does not have one (or is named differently) simply implement
the `ping` method on the class. Any successful response will count as
up, anything else will not.

```ruby
class MyService < Thrifer.build(MyService::Client)
  include Thrifer::Ping

  # Define a ping method if the service does not have one
  def ping
    my_other_rpc
  end
end

# my_service.up? # => true
```

## Contributing

1. Fork it ( https://github.com/saltside/thrifter/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
