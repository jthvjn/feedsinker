# FeedSink

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `feed_sinker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:feed_sinker, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/feed_sinker](https://hexdocs.pm/feed_sinker).


Requirements
1. Elixir
2. Postgres: 
     user: postgres, password: postgres
3. Redis: 
    No password
4. Check config/congig.exs

To setup the project:
$ mix setup


Architecture
1. Application starts
    a. Repo
    b. Task Supervisor
    c. calls a fn to add to Task Supervisor - [1]

2. Fn to add to Task Supervisor [1]
    a. Adds a supervised task for each feed  source with transient restart - [2]

3. [2] starts tasks to download the feed from the source at mentioned interval with temporary restart - [3]

4. [3] downloads the feed, normalize and adds to ExQ for persisting



