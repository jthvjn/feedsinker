defmodule FeedSink.Adapters.MatchBeam do
  @behaviour FeedSink.FeedSourceAdapter

  @source "matchbeam"

  require Logger
  alias FeedSink.{Feed, Helper}

  @impl true
  def source(), do: @source

  @impl true
  def get_url(), do: "http://forzaassignment.forzafootball.com:8080/feed/matchbeam"

  @impl true
  def normalize(%{"matches" => feeds}) do
    normalized_feeds =
    feeds
    |> Enum.reduce([], fn feed, acc ->
      [home_team, away_team] = String.split(feed["teams"], ~r{\s-\s}, [parts: 2, trim: true])

        feed_ = %{
          home_team: String.trim(home_team),
          away_team: String.trim(away_team),
          source: @source,
          created_at: DateTime.from_unix!(feed["created_at"]),
          kickoff_at: Helper.from_iso8601(feed["kickoff_at"])
        }

        changeset = Feed.changeset(feed_)
        if changeset.valid? do
           [struct(Feed, feed_)] ++ acc
        else
          Logger.error("#{__MODULE__}[Normalize][Failed] Received #{inspect feed} caused #{inspect changeset.errors}")
          acc
        end
    end)

    {:ok, normalized_feeds, @source}
  end

  def normalize(feeds_received) do
    Logger.error("#{__MODULE__}[Normalize][Failed][Invalid format] #{inspect feeds_received}")
    {:error, "#{__MODULE__} #{inspect feeds_received}", @source}
  end
end
