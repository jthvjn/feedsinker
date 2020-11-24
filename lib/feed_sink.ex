defmodule FeedSink do
  @moduledoc """
  Documentation for `FeedSink`.
  """
  require Logger
  use Task

  @headers []
  @options [
    timeout: 10_000,
    recv_timeout: 5_000
  ]

  def start() do
    IO.puts("\n
    ########################################
    ######### F E E D  s I N K E R #########
    ########################################
    \n")

    set_last_updated_timestamps

    Application.fetch_env!(:feed_sinker, :sources)
    |> Enum.each(fn {source, source_config} ->
      adapter = Map.get(source_config, :adapter)
      url = adapter.get_url
      request_interval = Map.get(source_config, :request_interval)
      Task.Supervisor.start_child(
        FeedSinkSupervisor,
        fn -> start_feed_sinker_for_source(source, url, request_interval) end,
        [restart: :transient]
      )
    end)
  end

  def start_feed_sinker_for_source(source, url, request_interval) do
    Logger.info("Starting feed downloader for #{source}")
    Task.start(__MODULE__, :get_and_save_feed_normalized, [url, source])
    Process.sleep(request_interval)
    start_feed_sinker_for_source(source, url, request_interval)
  end

  def get_and_save_feed_normalized(url, source) do
    url
    |> get_feeds_from(source)
    |> normalize_feeds()
    |> add_normalized_feeds_to_sink
  end


  defp get_feeds_from(url, source) do
    with {:ok, response = %HTTPoison.Response{}} <- HTTPoison.get(url, @headers, @options),
      {:ok, response_} <- Jason.decode(response.body) do
      Logger.info("[#{__MODULE__}][#{source}][#{url}] #{inspect(response_)}")
      {:ok, response_, source}
    else
      {:error, error} ->
        Logger.error("[#{__MODULE__}][#{source}][#{url}] #{inspect(error)} ")
        {:error, error, source}
    end
  end

  defp normalize_feeds({:ok, feeds, source}) do
    Application.fetch_env!(:feed_sinker, :sources)
    |> Keyword.get(source)
    |> Map.get(:adapter)
    |> apply(:normalize, [feeds])
  end

  defp normalize_feeds({:error, error, source}) do
    Logger.error("[#{__MODULE__}] #{inspect(error)}")
    {:error, error, source}
  end

  defp add_normalized_feeds_to_sink({:ok, normalized_feeds, source}) do
    Exq.enqueue(Exq, "feed_sink", FeedSink.Worker, [normalized_feeds, source])
  end

  defp add_normalized_feeds_to_sink({:error, error, source}) do
    Logger.error("[#{__MODULE__}] #{inspect(error)}")
  end

  def get_last_updated_timestamp_for(source) when is_atom(source) do
    case :ets.lookup(:last_updated_timestamp_table, source) do
      [] -> []
      [{_key, last_updated_timestamp}] -> last_updated_timestamp
    end
  end

  def get_last_updated_timestamp_for(source) when is_binary(source) do
    case :ets.lookup(:last_updated_timestamp_table, String.to_atom(source)) do
      [] -> []
      [{_key, last_updated_timestamp}] -> last_updated_timestamp
    end
  end

  def update_last_updated_timestamp_for(source, last_updated_timestamp) when is_atom(source) do
    :ets.insert(:last_updated_timestamp_table, {source, last_updated_timestamp})
  end

  def update_last_updated_timestamp_for(source, last_updated_timestamp) when is_binary(source) do
    :ets.insert(:last_updated_timestamp_table, {String.to_atom(source), last_updated_timestamp})
  end

  defp set_last_updated_timestamps do
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
