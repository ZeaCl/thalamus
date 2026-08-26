defmodule Thalamus.Infrastructure.Repositories.PostgreSQLEnvironmentRepositoryTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Domain.Entities.{Environment, Organization}

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLEnvironmentRepository,
    PostgreSQLOrganizationRepository
  }

  setup do
    {:ok, org} =
      Organization.new(
        "Test Org #{System.unique_integer([:positive])}",
        "owner_#{System.unique_integer([:positive])}@example.com",
        :free
      )

    {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)

    %{org: saved_org}
  end

  describe "create/1 and get/1" do
    test "creates an environment and retrieves by id", %{org: org} do
      attrs = %{
        organization_id: org.id,
        slug: "staging",
        name: "Staging QA",
        type: :staging,
        is_default: false,
        status: :active,
        description: "Staging testing environment"
      }

      assert {:ok, %Environment{} = env} = PostgreSQLEnvironmentRepository.create(attrs)
      assert env.slug == "staging"
      assert env.name == "Staging QA"
      assert env.organization_id == String.replace_prefix(to_string(org.id), "org_", "")

      assert {:ok, retrieved} = PostgreSQLEnvironmentRepository.get(env.id)
      assert retrieved.id == env.id
      assert retrieved.slug == "staging"
    end

    test "enforces unique slug per organization", %{org: org} do
      attrs = %{
        organization_id: org.id,
        slug: "staging",
        name: "Staging QA",
        type: :staging
      }

      assert {:ok, _} = PostgreSQLEnvironmentRepository.create(attrs)
      assert {:error, changeset} = PostgreSQLEnvironmentRepository.create(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  describe "get_by_slug/2" do
    test "finds environment by organization_id and slug", %{org: org} do
      {:ok, created} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "custom-sandbox",
          name: "Sandbox",
          type: :sandbox
        })

      assert {:ok, env} = PostgreSQLEnvironmentRepository.get_by_slug(org.id, "custom-sandbox")
      assert env.id == created.id
      assert env.slug == "custom-sandbox"
    end

    test "returns not_found if slug does not exist in org", %{org: org} do
      assert {:error, :not_found} =
               PostgreSQLEnvironmentRepository.get_by_slug(org.id, "nonexistent")
    end
  end

  describe "set_default/2 and get_default/1" do
    test "sets default atomically unsetting prior defaults", %{org: org} do
      {:ok, env1} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "production",
          name: "Prod",
          type: :production,
          is_default: true
        })

      {:ok, env2} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "staging",
          name: "Staging",
          type: :staging,
          is_default: false
        })

      assert {:ok, current_default} = PostgreSQLEnvironmentRepository.get_default(org.id)
      assert current_default.id == env1.id

      # Switch default to staging
      assert {:ok, new_default} = PostgreSQLEnvironmentRepository.set_default(org.id, env2.id)
      assert new_default.id == env2.id
      assert new_default.is_default == true

      # Verify env1 is no longer default
      assert {:ok, updated_env1} = PostgreSQLEnvironmentRepository.get(env1.id)
      assert updated_env1.is_default == false
    end
  end

  describe "list_by_organization/2" do
    test "lists active environments and filters archived", %{org: org} do
      {:ok, _env1} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "dev",
          name: "Development",
          type: :development,
          status: :active
        })

      {:ok, _env2} =
        PostgreSQLEnvironmentRepository.create(%{
          organization_id: org.id,
          slug: "archived-test",
          name: "Archived",
          type: :sandbox,
          status: :archived
        })

      {:ok, list_default} = PostgreSQLEnvironmentRepository.list_by_organization(org.id)
      slugs_default = Enum.map(list_default, & &1.slug)
      assert "dev" in slugs_default
      refute "archived-test" in slugs_default

      {:ok, list_all} =
        PostgreSQLEnvironmentRepository.list_by_organization(org.id, %{include_archived: true})

      slugs_all = Enum.map(list_all, & &1.slug)
      assert "dev" in slugs_all
      assert "archived-test" in slugs_all
    end
  end
end
