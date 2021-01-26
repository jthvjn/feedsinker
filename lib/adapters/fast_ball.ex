defmodule FeedSink.Adapters.FastBall do
  @behaviour FeedSink.FeedSourceAdapter

  require Logger
  alias FeedSink.{Feed, Helper}

  @source "fastball"

  @impl true
  def source(), do: @source

  @impl true
  def get_url() do
    case Helper.get_last_updated_timestamp_for(@source) do
      [] ->
        "http://forzaassignment.forzafootball.com:8080/feed/fastball"

      last_checked_at ->
        timestamp =
          last_checked_at
          |> DateTime.to_unix()

        "http://forzaassignment.forzafootball.com:8080/feed/fastball?last_checked_at=#{timestamp}"
    end
  end

  @impl true
  def normalize(%{"matches" => feeds}) do
    normalized_feeds =
      feeds
      |> Enum.reduce([], fn feed, acc ->
        feed_ = %{
          home_team: feed["home_team"],
          away_team: feed["away_team"],
          source: @source,
          created_at: DateTime.from_unix!(feed["created_at"]),
          kickoff_at: Helper.from_iso8601(feed["kickoff_at"])
        }

        changeset = Feed.changeset(feed_)

        if changeset.valid? do
          [struct(Feed, feed_)] ++ acc
        else
          Logger.error(
            "#{__MODULE__}[Normalize][Failed] Received #{inspect(feed)} caused #{
              inspect(changeset.errors)
            }"
          )

          acc
        end
      end)

    {:ok, normalized_feeds, @source}
  end

  def normalize(feeds_received) do
    Logger.error("#{__MODULE__}Normalize][Failed][Invalid format] #{inspect(feeds_received)}")
    {:error, "#{__MODULE__}  #{inspect(feeds_received)}", @source}
  end
end
