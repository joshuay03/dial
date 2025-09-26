# Dial

![Version](https://img.shields.io/gem/v/dial)
![Build](https://img.shields.io/github/actions/workflow/status/joshuay03/dial/.github/workflows/main.yml?branch=main)

A modern profiler for your Rails application.

Utilizes [vernier](https://github.com/jhawthorn/vernier) for profiling and
[prosopite](https://github.com/charkost/prosopite) for N+1 query detection.

> [!NOTE]
> Check out the resources in the vernier project for more information on how to
> interpret the viewer, as well as comparisons with other profilers, including stackprof.

![Demo](demo.gif)

## Installation

1. Add the gem to your Rails application's Gemfile:

```ruby
gem "dial"
```

2. Install the gem:

```bash
bundle install
```

3. Mount the engine in your `config/routes.rb` file:

```ruby
# this will mount the engine at /dial
mount Dial::Engine, at: "/"
```

4. (Optional) Configure the gem in an initializer:

```ruby
# config/initializers/dial.rb

Dial.configure do |config|
  config.enabled = !Rails.env.production? # disable by default in production, use force_param to enable per request
  config.force_param = "profile" # override param name to force profiling
  if Rails.env.staging?
    config.sampling_percentage = 50 # override sampling percentage in staging for A/B testing profiler impact
  end
  unless Rails.env.development?
    config.storage = Dial::Storage::RedisAdapter # use Redis storage in non-development environments
    config.storage_options = { client: Redis.new(url: ENV["REDIS_URL"]), ttl: 86400 }
  end
  config.vernier_interval = 100
  config.vernier_allocation_interval = 10_000
  config.prosopite_ignore_queries += [/pg_sleep/i]
end
```

## Options

Option | Description | Default
:- | :- | :-
`enabled` | Whether profiling is enabled. | `true`
`force_param` | Request parameter name to force profiling even when disabled. Always profiles (bypasses sampling). | `"dial_force"`
`sampling_percentage` | Percentage of requests to profile. | `100` in development, `1` in production
`storage` | Storage adapter class for profile data. | `Dial::Storage::FileAdapter`
`storage_options` | Options hash passed to storage adapter. | `{ ttl: 3600 }`
`content_security_policy_nonce` | Sets the content security policy nonce to use when inserting Dial's script. Can be a string, or a Proc which receives `env` and response `headers` as arguments and returns the nonce string. | Rails generated nonce or `nil`
`vernier_interval` | Sets the `interval` option for vernier. | `200`
`vernier_allocation_interval` | Sets the `allocation_interval` option for vernier. | `2_000`
`prosopite_ignore_queries` | Sets the `ignore_queries` option for prosopite. | `[/schema_migrations/i]`

## Storage Backends

### File Storage (Default)

Profile data is stored as files on disk with polled expiration. Only suitable for development and single-server deployments.

```ruby
Dial.configure do |config|
  config.storage = Dial::Storage::FileAdapter
  config.storage_options = { ttl: 86400 }
end
```

### Redis Storage

Profile data is stored in Redis with automatic expiration. Supports both single Redis instances and Redis Cluster.

```ruby
# Single Redis instance
Dial.configure do |config|
  config.storage = Dial::Storage::RedisAdapter
  config.storage_options = { client: Redis.new(url: "redis://localhost:6379"), ttl: 86400 }
end

# Redis Cluster
Dial.configure do |config|
  config.storage = Dial::Storage::RedisAdapter
  config.storage_options = {
    client: Redis::Cluster.new(nodes: [
      "redis://node1:7000",
      "redis://node2:7001",
      "redis://node3:7002"
    ]),
    ttl: 86400
  }
end
```

### Memcached Storage

Profile data is stored in Memcached with automatic expiration.

```ruby
Dial.configure do |config|
  config.storage = Dial::Storage::MemcachedAdapter
  config.storage_options = { client: Dalli::Client.new("localhost:11211"), ttl: 86400 }
end
```

## Comparison with [rack-mini-profiler](https://github.com/MiniProfiler/rack-mini-profiler)

|                           | rack-mini-profiler                 | Dial                                                    |
| :------------------------ | :--------------------------------- | :------------------------------------------------------ |
| Compatibility             | Any Rack application               | Only Rails applications                                 |
| Database Profiling        | Yes                                | Yes (via vernier hook - marker table, chart)            |
| N+1 Query Detection       | Yes (*needs to be inferred)        | Yes (via prosopite)                                     |
| Ruby Profiling            | Yes (with stackprof - flame graph) | Yes (via vernier - flame graph, stack chart, call tree) |
| Ruby Allocation Profiling | Yes (with stackprof - flame graph) | Yes (via vernier - flame graph, stack chart, call tree) |
| Memory Profiling          | Yes (with memory_profiler)         | Yes (*overall usage only) (via vernier hook - graph)    |
| View Profiling            | Yes                                | Yes (via vernier hook - marker table, chart)            |
| Snapshot Sampling         | Yes                                | No                                                      |
| Storage Backends          | Redis, Memcached, File, Memory     | Redis, Memcached, File                                  |
| Production Ready          | Yes                                | Yes                                                     |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake test` to run the
tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Testing Storage Adapters

To test the Redis and Memcached storage adapters, you'll need running instances: `docker compose -f docker-compose.storage.yml up`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joshuay03/dial.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Dial project's codebase and issue tracker is expected to follow the
[code of conduct](https://github.com/joshuay03/dial/blob/main/CODE_OF_CONDUCT.md).
