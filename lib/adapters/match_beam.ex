defmodule FeedSink.Adapters.MatchBeam do
  @source "matchbeam"

  require Logger
  def get_url(), do: "http://forzaassignment.forzafootball.com:8080/feed/matchbeam"

  def normalize(%{"matches" => feeds}) do
    normalized_feeds =
    feeds
    |> Enum.reduce([], fn feed, acc ->
      [home_team, away_team] = String.split(feed["teams"], ~r{\s-\s}, [parts: 2, trim: true])
        [%{
          home_team: String.trim(home_team),
          away_team: String.trim(away_team),
          source: @source,
          created_at: DateTime.from_unix!(feed["created_at"]) |> DateTime.to_iso8601(),
          kickoff_at: feed["kickoff_at"]
        }] ++ acc
    end)

    {:ok, normalized_feeds, @source}
  end

  def normalize(feeds_received) do
    Logger.error("#{__MODULE__}  #{inspect feeds_received}")
    {:error, "#{__MODULE__} #{inspect feeds_received}", @source}
  end
end
