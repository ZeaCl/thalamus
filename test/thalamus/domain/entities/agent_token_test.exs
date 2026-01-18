defmodule Thalamus.Domain.Entities.AgentTokenTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  describe "create/1 - happy path" do
    test "creates autonomous agent token with minimal attributes" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()

      attrs = %{
        access_token: "at_test123",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:ok, token} = AgentToken.create(attrs)
      assert token.access_token == "at_test123"
      assert token.agent_type == agent_type
      assert token.scopes == ["read:data"]
      assert token.revoked_at == nil
      assert is_binary(token.id)
    end

    test "creates supervisor agent token with all optional fields" do
      {:ok, agent_type} = AgentType.new("supervisor")
      {:ok, task_id} = TaskId.new(Ecto.UUID.generate())
      {:ok, chain} = DelegationChain.root()

      attrs = %{
        access_token: "at_supervisor_token",
        agent_type: agent_type,
        task_id: task_id,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data", "write:data"],
        delegation_chain: chain,
        reason: "Coordinating sub-agents for data processing",
        expires_at: DateTime.utc_now() |> DateTime.add(1800, :second)
      }

      assert {:ok, token} = AgentToken.create(attrs)
      assert token.task_id == task_id
      assert token.reason == "Coordinating sub-agents for data processing"
      assert length(token.scopes) == 2
    end

    test "creates tool agent token" do
      {:ok, agent_type} = AgentType.new("tool")
      {:ok, chain} = DelegationChain.root()

      attrs = %{
        access_token: "at_tool_xyz",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["tool:execute"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      assert {:ok, token} = AgentToken.create(attrs)
      assert token.agent_type.value == :tool
    end

    test "sets default delegation_chain if not provided" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_default_chain",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:ok, token} = AgentToken.create(attrs)
      assert DelegationChain.depth(token.delegation_chain) == 0
    end

    test "sets created_at to current time" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_timestamp",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      before = DateTime.utc_now()
      {:ok, token} = AgentToken.create(attrs)
      after_time = DateTime.utc_now()

      assert DateTime.compare(token.created_at, before) in [:gt, :eq]
      assert DateTime.compare(token.created_at, after_time) in [:lt, :eq]
    end
  end

  describe "create/1 - validation errors" do
    test "returns error when access_token is missing" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, {:missing_required_fields, missing}} = AgentToken.create(attrs)
      assert :access_token in missing
    end

    test "returns error when agent_type is missing" do
      attrs = %{
        access_token: "at_test",
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, {:missing_required_fields, missing}} = AgentToken.create(attrs)
      assert :agent_type in missing
    end

    test "returns error when organization_id is missing" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_test",
        agent_type: agent_type,
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, {:missing_required_fields, missing}} = AgentToken.create(attrs)
      assert :organization_id in missing
    end

    test "returns error when scopes is empty list" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_test",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: [],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, :empty_scopes} = AgentToken.create(attrs)
    end

    test "returns error when organization_id is invalid UUID" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_test",
        agent_type: agent_type,
        organization_id: "not-a-uuid",
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, :invalid_organization_id} = AgentToken.create(attrs)
    end

    test "returns error when client_id is invalid UUID" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_test",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: "invalid",
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, :invalid_client_id} = AgentToken.create(attrs)
    end

    test "returns error when expires_at is in the past" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_test",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
      }

      assert {:error, :expiration_in_past} = AgentToken.create(attrs)
    end

    test "returns error when agent_type is not AgentType value object" do
      attrs = %{
        access_token: "at_test",
        agent_type: "autonomous",  # String instead of AgentType
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      assert {:error, :invalid_agent_type} = AgentToken.create(attrs)
    end
  end

  describe "revoke/1" do
    test "sets revoked_at timestamp" do
      {:ok, token} = create_valid_token()

      assert token.revoked_at == nil

      {:ok, revoked_token} = AgentToken.revoke(token)

      assert %DateTime{} = revoked_token.revoked_at
      assert DateTime.compare(revoked_token.revoked_at, DateTime.utc_now()) in [:eq, :lt]
    end

    test "can revoke already revoked token (idempotent)" do
      {:ok, token} = create_valid_token()
      {:ok, revoked_once} = AgentToken.revoke(token)
      {:ok, revoked_twice} = AgentToken.revoke(revoked_once)

      assert %DateTime{} = revoked_twice.revoked_at
    end
  end

  describe "active?/1" do
    test "returns true for non-revoked, non-expired token" do
      {:ok, token} = create_valid_token()

      assert AgentToken.active?(token) == true
    end

    test "returns false for revoked token" do
      {:ok, token} = create_valid_token()
      {:ok, revoked_token} = AgentToken.revoke(token)

      assert AgentToken.active?(revoked_token) == false
    end

    test "returns false for expired token" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_expired",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        # Expires in 1 second
        expires_at: DateTime.utc_now() |> DateTime.add(1, :second)
      }

      {:ok, token} = AgentToken.create(attrs)

      # Wait for expiration
      Process.sleep(1100)

      assert AgentToken.active?(token) == false
    end
  end

  describe "expired?/1" do
    test "returns false for non-expired token" do
      {:ok, token} = create_valid_token()

      assert AgentToken.expired?(token) == false
    end

    test "returns true for expired token" do
      {:ok, agent_type} = AgentType.new("autonomous")

      attrs = %{
        access_token: "at_expired",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data"],
        expires_at: DateTime.utc_now() |> DateTime.add(1, :second)
      }

      {:ok, token} = AgentToken.create(attrs)

      Process.sleep(1100)

      assert AgentToken.expired?(token) == true
    end
  end

  describe "revoked?/1" do
    test "returns false for non-revoked token" do
      {:ok, token} = create_valid_token()

      assert AgentToken.revoked?(token) == false
    end

    test "returns true for revoked token" do
      {:ok, token} = create_valid_token()
      {:ok, revoked_token} = AgentToken.revoke(token)

      assert AgentToken.revoked?(revoked_token) == true
    end
  end

  # Helper function
  defp create_valid_token do
    {:ok, agent_type} = AgentType.new("autonomous")

    attrs = %{
      access_token: "at_valid_token",
      agent_type: agent_type,
      organization_id: Ecto.UUID.generate(),
      client_id: Ecto.UUID.generate(),
      scopes: ["read:data"],
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
    }

    AgentToken.create(attrs)
  end
end
