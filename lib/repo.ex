defmodule FeedSink.Repo do
  use Ecto.Repo,
    otp_app: :feed_sinker,
    adapter: Ecto.Adapters.Postgres
end
