defmodule FeedSink do
  @moduledoc """
  Documentation for `FeedSink`.

  Check `FeedSourceAdapter` for more defining new adapter.
  """
  require Logger
  use Task

  alias FeedSink.Helper

  @headers []
  @options [
    timeout: 10_000,
    recv_timeout: 5_000
  ]

  @doc """
    Adds a feed downloader for each source mention in `config.exs` under a supervisor
    with `restart: :transient`.
  """
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

  @doc """
    Starts a `feed sinker` process at every mentioned time intervals with `restart: :temporary`.
    The `feed sinker` process, downloads, normalize with the corresponding adapter, and pushes the
    data to `ExQ` for persistance. Data correctness is checked during normalization with the `Feed` schems.
  """
  def start_feed_sinker_for_source(source, url, request_interval) do
    Task.start(__MODULE__, :feed_sinker_for_source, [url, source])
    Process.sleep(request_interval)
    start_feed_sinker_for_source(source, url, request_interval)
  end

  def feed_sinker_for_source(url, source) do
    url
    |> get_feeds_from(source)
    |> log_status(:download_job, source)
    |> normalize_feeds()
    |> log_status(:normalize_job, source)
    |> add_normalized_feeds_to_sink
    |> log_status(:enqueue_job, source)
  end

  defp get_feeds_from(url, source) do
    Logger.info("Starting feed downloading for #{source} at #{DateTime.utc_now()}")

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
    with {:ok, jid} <- Exq.enqueue(Exq, "feed_sink", FeedSink.Worker, [normalized_feeds, source]) do
      {:ok, jid, source}
    else
      {:error, reason} ->
        Logger.error(
          "#{__MODULE__} [Feed sink queued][Failed][Feed sink] with reason #{inspect(reason)} for #{
            inspect(normalized_feeds)
          }"
        )

        {:error, reason, source}
    end
  end

  defp add_normalized_feeds_to_sink({:error, error, source}), do: error

  defp log_status(status, from, feed_source) do
    log(status, from, feed_source)

    status
  end

  defp log({:ok, jid, _}, :enqueue_job, source),
    do: Logger.info("#{__MODULE__} [Feed sink queued][Success] with JID #{inspect(jid)}")

  defp log({:error, reason, _}, :enqueue_job, source),
    do: Logger.error("#{__MODULE__} [Feed sink queued][Failed][Feed sink]")

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
