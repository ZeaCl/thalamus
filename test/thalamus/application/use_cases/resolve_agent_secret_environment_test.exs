defmodule Thalamus.Application.UseCases.ResolveAgentSecretEnvironmentTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Application.UseCases.ResolveAgentSecret
  alias Thalamus.Domain.Entities.{Secret, Organization, User}

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLSecretRepository,
    PostgreSQLOrganizationRepository,
    PostgreSQLUserRepository,
    PostgreSQLEnvironmentRepository
  }

  setup do
    {:ok, org} =
      Organization.new(
        "Secret Org #{System.unique_integer([:positive])}",
        "owner_#{System.unique_integer([:positive])}@test.com",
        :standard
      )

    {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)

    {:ok, user} =
      User.register("secret_user_#{System.unique_integer([:positive])}@test.com", "Password123!")

    {:ok, saved_user} = PostgreSQLUserRepository.save(user)

    {:ok, env_dev} =
      PostgreSQLEnvironmentRepository.create(%{
        organization_id: saved_org.id,
        slug: "development",
        name: "Development",
        type: :development
      })

    {:ok, env_prod} =
      PostgreSQLEnvironmentRepository.create(%{
        organization_id: saved_org.id,
        slug: "production",
        name: "Production",
        type: :production,
        is_default: true
      })

    org_uuid = String.replace_prefix(to_string(saved_org.id), "org_", "")
    user_uuid = String.replace_prefix(to_string(saved_user.id), "user_", "")

    %{
      org_id: org_uuid,
      user_id: user_uuid,
      env_dev_id: env_dev.id,
      env_prod_id: env_prod.id
    }
  end

  describe "ResolveAgentSecret with environment scoping" do
    test "resolves environment-specific secret over global secret", ctx do
      # Global org secret for openai
      {:ok, _} =
        PostgreSQLSecretRepository.create(%{
          owner_type: "organization",
          owner_id: ctx.org_id,
          provider: "openai",
          name: "Global OpenAI Key",
          value: "sk-global-org",
          environment_id: nil
        })

      # Dev environment secret for openai
      {:ok, dev_secret} =
        PostgreSQLSecretRepository.create(%{
          owner_type: "organization",
          owner_id: ctx.org_id,
          provider: "openai",
          name: "Dev OpenAI Key",
          value: "sk-dev-org",
          environment_id: ctx.env_dev_id
        })

      # Resolving in dev environment returns dev secret
      assert {:ok, %Secret{} = secret} =
               ResolveAgentSecret.execute("openai", ctx.org_id, ctx.user_id,
                 environment_id: ctx.env_dev_id
               )

      assert secret.id == dev_secret.id
      assert secret.value == "sk-dev-org"

      # Resolving in prod environment (where no prod secret exists) falls back to global secret
      assert {:ok, %Secret{} = fallback_secret} =
               ResolveAgentSecret.execute("openai", ctx.org_id, ctx.user_id,
                 environment_id: ctx.env_prod_id
               )

      assert fallback_secret.value == "sk-global-org"
    end

    test "respects prefer_user with environment resolution hierarchy", ctx do
      # Org secret for staging
      {:ok, _} =
        PostgreSQLSecretRepository.create(%{
          owner_type: "organization",
          owner_id: ctx.org_id,
          provider: "anthropic",
          name: "Org Claude Staging",
          value: "sk-ant-org-staging",
          environment_id: ctx.env_dev_id
        })

      # User secret for staging
      {:ok, user_secret} =
        PostgreSQLSecretRepository.create(%{
          owner_type: "user",
          owner_id: ctx.user_id,
          provider: "anthropic",
          name: "User Claude Staging",
          value: "sk-ant-user-staging",
          environment_id: ctx.env_dev_id
        })

      # Prefer user returns user secret for staging
      assert {:ok, secret} =
               ResolveAgentSecret.execute("anthropic", ctx.org_id, ctx.user_id,
                 prefer_user: true,
                 environment_id: ctx.env_dev_id
               )

      assert secret.id == user_secret.id
      assert secret.value == "sk-ant-user-staging"

      # Default (prefer org) returns org secret for staging
      assert {:ok, org_res} =
               ResolveAgentSecret.execute("anthropic", ctx.org_id, ctx.user_id,
                 prefer_user: false,
                 environment_id: ctx.env_dev_id
               )

      assert org_res.value == "sk-ant-org-staging"
    end

    test "handles non-UUID environment safely without raising CastError", ctx do
      {:ok, _} =
        PostgreSQLSecretRepository.create(%{
          owner_type: "organization",
          owner_id: ctx.org_id,
          provider: "mistral",
          name: "Global Mistral Key",
          value: "sk-global-mistral",
          environment_id: nil
        })

      # Passing slug or invalid UUID doesn't crash, falls back to global
      assert {:ok, secret} =
               ResolveAgentSecret.execute("mistral", ctx.org_id, ctx.user_id,
                 environment_id: "production"
               )

      assert secret.value == "sk-global-mistral"
    end
  end
end
