defmodule Thalamus.Domain.Entities.EnvironmentTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.Environment

  describe "new/1" do
    test "creates environment with valid attributes" do
      attrs = %{
        organization_id: "org_12345",
        slug: "staging",
        name: "Staging QA",
        type: :staging,
        is_default: false,
        status: :active,
        description: "Staging testing environment"
      }

      assert {:ok, %Environment{} = env} = Environment.new(attrs)
      assert env.slug == "staging"
      assert env.name == "Staging QA"
      assert env.type == :staging
      assert env.is_default == false
      assert env.status == :active
    end

    test "normalizes slug to lowercase" do
      attrs = %{
        organization_id: "org_12345",
        slug: "  PROD-US-EAST  ",
        name: "Production US",
        type: :production
      }

      assert {:ok, env} = Environment.new(attrs)
      assert env.slug == "prod-us-east"
    end

    test "rejects missing organization_id" do
      attrs = %{slug: "dev", name: "Development"}
      assert {:error, :missing_organization_id} = Environment.new(attrs)
    end

    test "rejects missing name" do
      attrs = %{organization_id: "org_123", slug: "dev"}
      assert {:error, :missing_name} = Environment.new(attrs)
    end

    test "rejects name too short" do
      attrs = %{organization_id: "org_123", slug: "dev", name: "A"}
      assert {:error, :name_too_short} = Environment.new(attrs)
    end

    test "rejects invalid slug format" do
      attrs = %{organization_id: "org_123", slug: "Dev_Env!", name: "Development"}
      assert {:error, :invalid_slug_format} = Environment.new(attrs)
    end

    test "rejects invalid type" do
      attrs = %{organization_id: "org_123", slug: "dev", name: "Development", type: :invalid_type}
      assert {:error, :invalid_environment_type} = Environment.new(attrs)
    end
  end

  describe "can_delete?/1" do
    test "protects default environments" do
      {:ok, env} =
        Environment.new(%{organization_id: "org_1", slug: "dev", name: "Dev", is_default: true})

      assert {:error, :cannot_delete_default_environment} = Environment.can_delete?(env)
    end

    test "protects production environments" do
      {:ok, env} =
        Environment.new(%{
          organization_id: "org_1",
          slug: "prod",
          name: "Prod",
          type: :production,
          is_default: false
        })

      assert {:error, :cannot_delete_production_environment} = Environment.can_delete?(env)
    end

    test "allows deleting non-default staging/dev environments" do
      {:ok, env} =
        Environment.new(%{
          organization_id: "org_1",
          slug: "dev",
          name: "Dev",
          type: :development,
          is_default: false
        })

      assert :ok = Environment.can_delete?(env)
    end
  end

  describe "state transitions" do
    test "suspend, activate, archive" do
      {:ok, env} =
        Environment.new(%{organization_id: "org_1", slug: "dev", name: "Dev", type: :development})

      assert env.status == :active

      assert {:ok, suspended} = Environment.suspend(env)
      assert suspended.status == :suspended

      assert {:ok, active} = Environment.activate(suspended)
      assert active.status == :active

      assert {:ok, archived} = Environment.archive(active)
      assert archived.status == :archived
    end
  end
end
