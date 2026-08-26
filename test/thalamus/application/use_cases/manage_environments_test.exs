defmodule Thalamus.Application.UseCases.ManageEnvironmentsTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Application.UseCases.ManageEnvironments
  alias Thalamus.Domain.Entities.Organization
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository

  setup do
    {:ok, org} =
      Organization.new(
        "Acme #{System.unique_integer([:positive])}",
        "owner_#{System.unique_integer([:positive])}@example.com",
        :standard
      )

    {:ok, saved_org} = PostgreSQLOrganizationRepository.save(org)

    %{org: saved_org}
  end

  describe "seed_default_environments/1" do
    test "creates production, staging, and development environments", %{org: org} do
      assert {:ok, results} = ManageEnvironments.seed_default_environments(org.id)
      assert length(results) == 3

      {:ok, envs} = ManageEnvironments.list_environments(org.id)
      slugs = Enum.map(envs, & &1.slug)
      assert "production" in slugs
      assert "staging" in slugs
      assert "development" in slugs

      prod_env = Enum.find(envs, &(&1.slug == "production"))
      assert prod_env.is_default == true
      assert prod_env.type == :production
    end

    test "is idempotent and does not duplicate existing base environments", %{org: org} do
      {:ok, _} = ManageEnvironments.seed_default_environments(org.id)
      {:ok, _} = ManageEnvironments.seed_default_environments(org.id)

      {:ok, envs} = ManageEnvironments.list_environments(org.id)
      assert length(envs) == 3
    end
  end

  describe "create_environment/2 and get_environment/2" do
    test "creates custom environment and retrieves by slug or id", %{org: org} do
      {:ok, env} =
        ManageEnvironments.create_environment(org.id, %{
          slug: "demo-client-a",
          name: "Demo Client A",
          type: :demo,
          description: "Demo environment for prospect"
        })

      assert env.slug == "demo-client-a"
      assert env.type == :demo

      # Get by slug
      assert {:ok, retrieved_by_slug} =
               ManageEnvironments.get_environment(org.id, "demo-client-a")

      assert retrieved_by_slug.id == env.id

      # Get by id
      assert {:ok, retrieved_by_id} = ManageEnvironments.get_environment(org.id, env.id)
      assert retrieved_by_id.slug == "demo-client-a"
    end
  end

  describe "delete_environment/3" do
    test "rejects deleting default environment", %{org: org} do
      {:ok, _} = ManageEnvironments.seed_default_environments(org.id)

      assert {:error, :cannot_delete_default_environment} =
               ManageEnvironments.delete_environment(org.id, "production")
    end

    test "archives non-default non-production environment", %{org: org} do
      {:ok, _} = ManageEnvironments.seed_default_environments(org.id)
      assert {:ok, archived} = ManageEnvironments.delete_environment(org.id, "development")
      assert archived.status == :archived

      {:ok, active_envs} = ManageEnvironments.list_environments(org.id)
      refute "development" in Enum.map(active_envs, & &1.slug)
    end
  end
end
