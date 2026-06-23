defmodule Thalamus.Domain.Entities.AgentTokenTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  describe "create/1 with valid inputs" do
    test "creates agent token with all required fields" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})

      params = %{
        client_id: "client-123",
        organization_id: "org-456",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Process financial reports",
        scopes: ["read:data", "write:results"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-789",
        expires_in: 3600
      }

      assert {:ok, token} = AgentToken.create(params)
      assert token.client_id == "client-123"
      assert token.organization_id == "org-456"
      assert token.agent_type == agent_type
      assert token.task_id == task_id
      assert token.task_description == "Process financial reports"
      assert token.scopes == ["read:data", "write:results"]
      assert token.delegation_chain == delegation_chain
      assert token.delegator_user_id == "user-789"
      assert token.expires_in == 3600
      assert token.status == :active
      assert token.revoked_at == nil
      assert is_binary(token.id)
      assert is_struct(token.created_at, DateTime)
    end

    test "generates unique UUID for id" do
      {:ok, agent_type} = AgentType.new(:tool)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task 1",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      {:ok, token1} = AgentToken.create(params)
      {:ok, token2} = AgentToken.create(params)

      assert token1.id != token2.id
    end

    test "sets created_at to current UTC time" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      before = DateTime.utc_now()
      {:ok, token} = AgentToken.create(params)
      after_time = DateTime.utc_now()

      assert DateTime.compare(token.created_at, before) in [:eq, :gt]
      assert DateTime.compare(token.created_at, after_time) in [:eq, :lt]
    end

    test "creates token with minimum scopes (empty list)" do
      {:ok, agent_type} = AgentType.new(:tool)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: [],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:ok, token} = AgentToken.create(params)
      assert token.scopes == []
    end

    test "creates token with optional reason field" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600,
        reason: "Automated workflow execution"
      }

      assert {:ok, token} = AgentToken.create(params)
      assert token.reason == "Automated workflow execution"
    end
  end

  describe "create/1 with invalid inputs" do
    test "fails with missing required fields" do
      assert {:error, :invalid_agent_token} = AgentToken.create(%{})
    end

    test "fails with nil client_id" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: nil,
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end

    test "fails with empty string client_id" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end

    test "fails with invalid agent_type" do
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: "not-an-agent-type",
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end

    test "fails with invalid task_id" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: "not-a-task-id",
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end

    test "fails with invalid delegation_chain" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: "not-a-chain",
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end

    test "fails with non-integer expires_in" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: "not-an-integer"
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end

    test "allows negative expires_in (for testing expired tokens)" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: ["read"],
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: -100
      }

      # Negative expires_in is technically valid (creates already-expired token)
      # Useful for testing expired token scenarios
      assert {:ok, token} = AgentToken.create(params)
      assert AgentToken.expired?(token)
    end

    test "fails with non-list scopes" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, delegation_chain} = DelegationChain.from_delegator("user-1")

      params = %{
        client_id: "client-1",
        organization_id: "org-1",
        agent_type: agent_type,
        task_id: task_id,
        task_description: "Task",
        scopes: "not-a-list",
        delegation_chain: delegation_chain,
        delegator_user_id: "user-1",
        expires_in: 3600
      }

      assert {:error, :invalid_agent_token} = AgentToken.create(params)
    end
  end

  describe "revoke/2" do
    test "revokes active token" do
      {:ok, token} = create_valid_token()

      assert {:ok, revoked_token} = AgentToken.revoke(token, "Manual revocation by user")

      assert revoked_token.status == :revoked
      assert revoked_token.revoke_reason == "Manual revocation by user"
      assert is_struct(revoked_token.revoked_at, DateTime)
    end

    test "sets revoked_at to current UTC time" do
      {:ok, token} = create_valid_token()

      before = DateTime.utc_now()
      {:ok, revoked_token} = AgentToken.revoke(token, "Revoked")
      after_time = DateTime.utc_now()

      assert DateTime.compare(revoked_token.revoked_at, before) in [:eq, :gt]
      assert DateTime.compare(revoked_token.revoked_at, after_time) in [:eq, :lt]
    end

    test "revoke with nil reason succeeds" do
      {:ok, token} = create_valid_token()

      assert {:ok, revoked_token} = AgentToken.revoke(token, nil)
      assert revoked_token.status == :revoked
      assert revoked_token.revoke_reason == nil
    end

    test "revoke with empty string reason succeeds" do
      {:ok, token} = create_valid_token()

      assert {:ok, revoked_token} = AgentToken.revoke(token, "")
      assert revoked_token.status == :revoked
      assert revoked_token.revoke_reason == ""
    end

    test "fails to revoke already revoked token" do
      {:ok, token} = create_valid_token()
      {:ok, revoked_token} = AgentToken.revoke(token, "First revocation")

      assert {:error, :already_revoked} = AgentToken.revoke(revoked_token, "Second revocation")
    end
  end

  describe "active?/1" do
    test "returns true for newly created token" do
      {:ok, token} = create_valid_token()
      assert AgentToken.active?(token)
    end

    test "returns false for revoked token" do
      {:ok, token} = create_valid_token()
      {:ok, revoked_token} = AgentToken.revoke(token, "Revoked")

      refute AgentToken.active?(revoked_token)
    end

    test "returns false for expired token" do
      {:ok, token} = create_valid_token(expires_in: -100)
      refute AgentToken.active?(token)
    end
  end

  describe "expired?/1" do
    test "returns false for non-expired token" do
      {:ok, token} = create_valid_token(expires_in: 3600)
      refute AgentToken.expired?(token)
    end

    test "returns true for expired token" do
      {:ok, token} = create_valid_token(expires_in: -100)
      assert AgentToken.expired?(token)
    end

    test "returns true when current time is exactly at expiration" do
      # Create token that expires in 0 seconds (expired immediately)
      {:ok, token} = create_valid_token(expires_in: 0)
      # Small delay to ensure time has passed
      Process.sleep(1)
      assert AgentToken.expired?(token)
    end

    test "returns false for token expiring in 1 second" do
      {:ok, token} = create_valid_token(expires_in: 1)
      refute AgentToken.expired?(token)
    end
  end

  describe "revoked?/1" do
    test "returns false for active token" do
      {:ok, token} = create_valid_token()
      refute AgentToken.revoked?(token)
    end

    test "returns true for revoked token" do
      {:ok, token} = create_valid_token()
      {:ok, revoked_token} = AgentToken.revoke(token, "Revoked")

      assert AgentToken.revoked?(revoked_token)
    end
  end

  describe "expires_at/1" do
    test "calculates expiration time from created_at and expires_in" do
      {:ok, token} = create_valid_token(expires_in: 3600)

      expected_expires_at = DateTime.add(token.created_at, 3600, :second)
      actual_expires_at = AgentToken.expires_at(token)

      assert DateTime.compare(actual_expires_at, expected_expires_at) == :eq
    end

    test "handles zero expires_in" do
      {:ok, token} = create_valid_token(expires_in: 0)

      expected_expires_at = token.created_at
      actual_expires_at = AgentToken.expires_at(token)

      assert DateTime.compare(actual_expires_at, expected_expires_at) == :eq
    end
  end

  describe "time_until_expiration/1" do
    test "returns positive seconds for non-expired token" do
      {:ok, token} = create_valid_token(expires_in: 3600)

      seconds = AgentToken.time_until_expiration(token)
      assert seconds > 0
      assert seconds <= 3600
    end

    test "returns negative seconds for expired token" do
      {:ok, token} = create_valid_token(expires_in: -100)

      seconds = AgentToken.time_until_expiration(token)
      assert seconds < 0
    end

    test "returns approximately 0 for token expiring now" do
      {:ok, token} = create_valid_token(expires_in: 0)

      seconds = AgentToken.time_until_expiration(token)
      # Allow 1 second margin
      assert seconds <= 1
    end
  end

  describe "equality" do
    test "tokens with same id are equal" do
      {:ok, token1} = create_valid_token()
      token2 = %{token1 | task_description: "Different description"}

      assert token1.id == token2.id
    end

    test "tokens with different ids are not equal" do
      {:ok, token1} = create_valid_token()
      {:ok, token2} = create_valid_token()

      assert token1.id != token2.id
    end
  end

  describe "pattern matching" do
    test "can pattern match on status" do
      {:ok, active_token} = create_valid_token()
      {:ok, revoked_token} = AgentToken.revoke(active_token, "Revoked")

      result1 =
        case active_token do
          %AgentToken{status: :active} -> :active_matched
          %AgentToken{status: :revoked} -> :revoked_matched
        end

      result2 =
        case revoked_token do
          %AgentToken{status: :revoked} -> :revoked_matched
        end

      assert result1 == :active_matched
      assert result2 == :revoked_matched
    end
  end

  describe "semantic meaning" do
    test "agent token represents permission for agent to act on behalf of user" do
      {:ok, token} = create_valid_token()

      # Token ties together:
      # - Who: delegator_user_id (the human who authorized)
      # - What: scopes (what permissions are granted)
      # - Why: task_description (what task is being performed)
      # - How long: expires_in (time limit)
      # - Audit: delegation_chain (hierarchy of delegations)

      assert token.delegator_user_id == "user-123"
      assert token.task_description == "Test task"
      assert token.scopes == ["read:data"]
      assert token.expires_in == 3600
      assert token.delegation_chain.depth == 0
    end

    test "delegation chain prevents infinite delegation loops" do
      # Root: User delegates to Agent A
      {:ok, root_token} = create_valid_token()
      assert root_token.delegation_chain.depth == 0

      # Agent A could create child token with depth 1, etc.
      # Maximum depth of 4 prevents runaway delegation
      refute DelegationChain.exceeds_max_depth?(root_token.delegation_chain)
    end
  end

  # Helper function to create a valid token for testing
  defp create_valid_token(opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)

    {:ok, agent_type} = AgentType.new(:autonomous)
    {:ok, task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
    {:ok, delegation_chain} = DelegationChain.from_delegator("user-123")

    params = %{
      client_id: "client-123",
      organization_id: "org-456",
      agent_type: agent_type,
      task_id: task_id,
      task_description: "Test task",
      scopes: ["read:data"],
      delegation_chain: delegation_chain,
      delegator_user_id: "user-123",
      expires_in: expires_in
    }

    AgentToken.create(params)
  end
end
