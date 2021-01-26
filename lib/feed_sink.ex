defmodule FeedSink do
  @moduledoc """
  Documentation for `FeedSink`.
  """
  require Logger
  use Task

  alias FeedSink.Helper

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

    Helper.set_last_updated_timestamps()

    Application.fetch_env!(:feed_sinker, :sources)
    |> Enum.each(fn {source, %{adapter: adapter, request_interval: request_interval}} ->
      Logger.info("Starting feed downloader for #{source}")

      Task.Supervisor.start_child(
        FeedSinkSupervisor,
        fn -> start_feed_sinker_for_source(source, adapter.get_url, request_interval) end,
        restart: :transient
      )
      |> log_status(:start_downloader, source)
    end)
  end

  def start_feed_sinker_for_source(source, url, request_interval) do
    Task.start(__MODULE__, :get_and_save_feed_normalized, [url, source])
    Process.sleep(request_interval)
    start_feed_sinker_for_source(source, url, request_interval)
  end

  def get_and_save_feed_normalized(url, source) do
    Logger.info("Starting feed downloading for #{source} at #{DateTime.utc_now()}")

    url
    |> get_feeds_from(source)
    |> log_status(:download_job, source)
    |> normalize_feeds()
    |> log_status(:normalize_job, source)
    |> add_normalized_feeds_to_sink
    |> log_status(:enqueue_job, source)
  end

  defp get_feeds_from(url, source) do
    with {:ok, response = %HTTPoison.Response{}} <- HTTPoison.get(url, @headers, @options),
         {:ok, response_} <- Jason.decode(response.body) do
      Logger.info("[#{__MODULE__}][Feed downloading][Success][#{source}][#{url}]}")
      {:ok, response_, source}
    else
      {:error, error} ->
        Logger.error(
          "[#{__MODULE__}][Feed downloading][Failed][#{source}][#{url}] #{inspect(error)} "
        )

        {:error, error, source}
    end
  end

  defp normalize_feeds({:ok, feeds, source}) do
    Application.fetch_env!(:feed_sinker, :sources)
    |> Keyword.get(source)
    |> Map.get(:adapter)
    |> apply(:normalize, [feeds])
  end

  defp normalize_feeds(error), do: error

  defp add_normalized_feeds_to_sink({:ok, normalized_feeds, source}) do
    Exq.enqueue(Exq, "feed_sink", FeedSink.Worker, [normalized_feeds, source])
  end

  defp add_normalized_feeds_to_sink({:error, error, source}), do: error

  defp log_status(status, from, feed_source) do
    log(status, from, feed_source)

    status
  end

  defp log({:ok, jid}, :enqueue_job, source),
    do: Logger.info("#{__MODULE__} [Feed sink queued][Success] with JID #{inspect(jid)}")

  defp log({:error, reason}, :enqueue_job, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed sink queued][Failed][Feed sink] with reason #{inspect(reason)}"
      )

  defp log({:ok, pid}, :start_downloader, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed downloader][Started] for #{source} with PID #{inspect(pid)}"
      )

  defp log({:ok, pid, _}, :start_downloader, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed downloader][Started] for #{source} with PID #{inspect(pid)}"
      )

  defp log({:error, {:already_started, pid}}, :start_downloader, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed downloader][Already started] for #{source} with PID #{inspect(pid)}"
      )

  defp log(:already_present, :start_downloader, source),
    do: Logger.info("#{__MODULE__} [Feed downloader][Already started] for #{source}")

  defp log(_, :start_downloader, source),
    do: Logger.error("#{__MODULE__} [Feed downloader][Status unknown] for #{source}")

  defp log({:ok, _, _}, :download_job, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed downloading][Success] Feed downloading from #{source} at #{
          inspect(DateTime.utc_now())
        }"
      )

  defp log({:error, _, _}, :download_job, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed downloading][Failed] Feed downloading from #{source} at #{
          inspect(DateTime.utc_now())
        }"
      )

  defp log({:ok, _, _}, :normalize_job, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed normalizing][Success] Feed normalizing from #{source} at #{
          inspect(DateTime.utc_now())
        }"
      )

  defp log({:error, _, _}, :normalize_job, source),
    do:
      Logger.info(
        "#{__MODULE__} [Feed normalizing][Failed] Feed normalizing from #{source} at #{
          inspect(DateTime.utc_now())
        }"
      )
end
