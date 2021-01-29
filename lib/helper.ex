defmodule FeedSink.Helper do
  require Logger

  def from_iso8601(datetime_string) do
    with {:ok, datetime, _} <- DateTime.from_iso8601(datetime_string) do
      datetime
    else
      _ = error ->
        Logger.error("#{__MODULE__} datetime_string cause #{inspect(error)}")

        nil
    end
  end

  def get_last_updated_timestamp_for(source) when is_atom(source) do
    case :ets.lookup(:last_updated_timestamp_table, source) do
      [] -> FeedSink.Feed.last_updated_timestamp(source)
      [{_key, last_updated_timestamp}] -> last_updated_timestamp
    end
  end

  def get_last_updated_timestamp_for(source) when is_binary(source) do
    source
    |> String.to_atom()
    |> get_last_updated_timestamp_for
  end

  def update_last_updated_timestamp_for(source, last_updated_timestamp) when is_atom(source) do
    :ets.insert(:last_updated_timestamp_table, {source, last_updated_timestamp})
  end

  def update_last_updated_timestamp_for(source, last_updated_timestamp) when is_binary(source) do
    source
    |> String.to_atom()
    |> update_last_updated_timestamp_for(last_updated_timestamp)
  end

  def set_last_updated_timestamps do
    Application.fetch_env!(:feed_sinker, :sources)
    |> Keyword.keys()
    |> Enum.each(fn source ->
      timestamp =
        case FeedSink.Feed.last_updated_timestamp(source) do
          nil ->
            DateTime.new!(~D[0001-01-01], ~T[00:00:00.000], "Etc/UTC")

          t ->
            t
        end

      update_last_updated_timestamp_for(source, timestamp)
    end)
  end
end
