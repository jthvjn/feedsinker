use Mix.Config

config :exq,
  name: Exq,
  host: "127.0.0.1",
  port: 6379,
  # password: "optional_redis_auth",
  namespace: "exq",
  concurrency: :infinite,
  queues: ["feed_sink"],
  poll_timeout: 50,
  scheduler_poll_timeout: 200,
  scheduler_enable: true,
  max_retries: 25,
  mode: :default,
  shutdown_timeout: 5000,
  start_on_application: true,
  dead_max_jobs: 10_000,
  dead_timeout_in_seconds: 1 * 24 * 60 * 60 # 1 day

config :feed_sinker,
  ecto_repos: [FeedSink.Repo]

config :feed_sinker, FeedSink.Repo,
  database: "feeds_store",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  # OR use a URL to connect instead
  url: "postgres://postgres:postgres@localhost/feeds_store"

config :feed_sinker,
  sources: [
    matchbeam: %{
      adapter: FeedSink.Adapters.MatchBeam,
      request_interval: 30_000
    },
    fastball: %{
      adapter: FeedSink.Adapters.FastBall,
      request_interval: 30_000
    }
  ]
