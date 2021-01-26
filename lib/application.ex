defmodule FeedSink.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {FeedSink.Repo, []},
      {Task.Supervisor, strategy: :one_for_one, name: FeedSinkSupervisor}
    ]

    # Create last_updated_timestamp_table
    create_last_updated_timestamp_table

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: FeedSink.Supervisor]

    return_val = Supervisor.start_link(children, opts)

    FeedSink.start()

    return_val
  end

  defp create_last_updated_timestamp_table() do
    :ets.new(:last_updated_timestamp_table, [:set, :public, :named_table])
  end
end
