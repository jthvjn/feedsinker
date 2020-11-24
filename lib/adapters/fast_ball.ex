defmodule FeedSink.Adapters.FastBall do

  require Logger

  @source "fastball"
  def get_url() do
    case FeedSink.get_last_updated_timestamp_for(@source) do
      [] ->
        "http://forzaassignment.forzafootball.com:8080/feed/fastball"

      last_checked_at ->
        timestamp =
          last_checked_at
          |> DateTime.to_unix
        "http://forzaassignment.forzafootball.com:8080/feed/fastball?last_checked_at=#{timestamp}"
    end
  end


  def normalize(%{"matches" => feeds}) do
    normalized_feeds =
    feeds
    |> Enum.reduce([], fn feed, acc ->
        [%{
          home_team: feed["home_team"],
          away_team: feed["away_team"],
          source: @source,
          created_at: DateTime.from_unix!(feed["created_at"]) |> DateTime.to_iso8601(),
          kickoff_at: feed["kickoff_at"]
        }] ++ acc
    end)
    {:ok, normalized_feeds, @source}
  end

  def normalize(feeds_received) do
    Logger.error("#{__MODULE__} #{inspect feeds_received}")
    {:error, "#{__MODULE__}  #{inspect feeds_received}", @source}
  end
end
