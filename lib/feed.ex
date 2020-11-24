defmodule FeedSink.Feed do
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  @fields [:home_team, :away_team, :source, :kickoff_at, :created_at]
  @required_fields @fields

  schema "feeds" do
    field :home_team, :string
    field :away_team, :string
    field :source, :string
    field :kickoff_at, :utc_datetime
    field :created_at, :utc_datetime

    timestamps()
  end

  def changeset(feed, params \\ %{}) do
    feed
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end

  def last_updated_timestamp(source) do
    query = from feed in __MODULE__,
      where: feed.source == ^to_string(source),
      select: max(feed.created_at)

    query
    |> FeedSink.Repo.one()
  end

  def insert(params) do
    %__MODULE__{}
    |> changeset(params)
    |> FeedSink.Repo.insert()
  end
end
