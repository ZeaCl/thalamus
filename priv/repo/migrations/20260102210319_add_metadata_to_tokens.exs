defmodule Thalamus.Repo.Migrations.AddMetadataToTokens do
  use Ecto.Migration

  def change do
    alter table(:tokens) do
      add :metadata, :map, default: %{}
    end
  end
end
