defmodule FeedSink.Repo.Migrations.Feeds do
  use Ecto.Migration

  def change do
    create table("feeds") do
      add :home_team, :string
      add :away_team, :string
      add :source, :string
      add :kickoff_at, :utc_datetime
      add :created_at, :utc_datetime

      timestamps()
    end

    # TODO
    # Create indices as per requirements/queries
    create index("feeds", [:source, :created_at])
  end
end
