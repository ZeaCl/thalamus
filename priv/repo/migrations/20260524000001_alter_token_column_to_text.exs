defmodule Thalamus.Infrastructure.Persistence.Migrations.AlterTokenColumnToText do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE tokens ALTER COLUMN token TYPE text"
  end

  def down do
    execute "ALTER TABLE tokens ALTER COLUMN token TYPE character varying(255)"
  end
end
