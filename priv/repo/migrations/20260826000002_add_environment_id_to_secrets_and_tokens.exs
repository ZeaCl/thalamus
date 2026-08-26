defmodule Thalamus.Repo.Migrations.AddEnvironmentIdToSecretsAndTokens do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      add :environment_id,
          references(:environments, type: :binary_id, on_delete: :nilify_all),
          null: true
    end

    create index(:secrets, [:owner_type, :owner_id, :provider, :environment_id],
             name: :idx_secrets_owner_provider_env
           )

    alter table(:agent_tokens) do
      add :environment_id,
          references(:environments, type: :binary_id, on_delete: :nilify_all),
          null: true

      add :environment_slug, :string, null: true
    end

    create index(:agent_tokens, [:environment_id], name: :idx_agent_tokens_environment_id)

    alter table(:tokens) do
      add :environment_id,
          references(:environments, type: :binary_id, on_delete: :nilify_all),
          null: true
    end

    create index(:tokens, [:environment_id], name: :idx_tokens_environment_id)
  end
end
