defmodule FeedSink.Worker do
  @moduledoc """
    Worker to persist data.
  """
  alias FeedSink.{Repo, Feed, Helper}
  require Logger

  def perform([], _) do
    :ok
  end

  def perform(feeds, source) do
    last_updated_timestamp = Helper.get_last_updated_timestamp_for(source)
    feeds
    |> Enum.reduce_while(
      last_updated_timestamp,
      fn feed, latest_timestamp ->
        {:ok, created_at_formatted, _} = DateTime.from_iso8601(feed["created_at"])
        {:ok, kickoff_at_formatted, _} = DateTime.from_iso8601(feed["kickoff_at"])

        feed =
          feed
          |> Map.put("created_at", created_at_formatted)
          |> Map.put("kickoff_at", kickoff_at_formatted)

        if is_new_feed?(created_at_formatted, latest_timestamp) do
          with {:ok, _ } <- Feed.insert(feed) do
            Helper.update_last_updated_timestamp_for(source, created_at_formatted)
            Logger.info("[#{__MODULE__}] Added to DB #{inspect feed}")
            {:cont, created_at_formatted}
          else
            {:error, _} ->
              Logger.error("[#{__MODULE__}] Failed to add to DB #{inspect feed}")
              {:halt, created_at_formatted}
          end
        else
          {:cont, latest_timestamp}
        end
      end)
  end

  defp is_new_feed?(feed_timestamp, last_updated_time_stamp) do
    case DateTime.compare(feed_timestamp, last_updated_time_stamp) do
      :lt -> false
      _   -> true
    end
  end
end
