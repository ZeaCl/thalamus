defmodule Thalamus.Application.UseCases.RevokeAgentTokenTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.RevokeAgentToken
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  # Setup Mox to verify expectations
  setup :verify_on_exit!

  describe "execute/2 - happy path" do
    test "revokes single token successfully" do
      request = valid_request()
      token = build_agent_token(request.organization_id)
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)
      |> expect(:revoke, fn _token_id, _reason -> {:ok, token} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.event_type == "agent_token.revoked"
        assert event.actor_id == request.revoked_by_user_id
        assert event.metadata.revocation_type == "single"
        :ok
      end)

      assert {:ok, :revoked} = RevokeAgentToken.execute(request, deps)
    end

    test "revokes token with cascade successfully" do
      request = %{valid_request() | cascade: true}
      token = build_agent_token(request.organization_id)
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)
      |> expect(:revoke_delegation_chain, fn _token_id, _reason -> {:ok, 5} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.event_type == "agent_token.revoked_cascade"
        assert event.metadata.revocation_type == "cascade"
        assert event.metadata.tokens_revoked == 5
        :ok
      end)

      assert {:ok, {:revoked_cascade, 5}} = RevokeAgentToken.execute(request, deps)
    end

    test "revokes token with reason" do
      request = %{valid_request() | reason: "Task completed"}
      token = build_agent_token(request.organization_id)
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)
      |> expect(:revoke, fn _token_id, reason ->
        assert reason == "Task completed"
        {:ok, token}
      end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.metadata.reason == "Task completed"
        :ok
      end)

      assert {:ok, :revoked} = RevokeAgentToken.execute(request, deps)
    end

    test "invalidates cache when cache service is provided" do
      request = valid_request()
      token = build_agent_token(request.organization_id)
      deps = build_deps_with_cache()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)
      |> expect(:revoke, fn _token_id, _reason -> {:ok, token} end)

      MockCacheService
      |> expect(:delete, fn key ->
        assert key == "agent_token:#{token.id}"
        :ok
      end)
      |> expect(:delete, fn key ->
        assert key == "agent_tokens:org:#{token.organization_id}"
        :ok
      end)

      MockAuditLogger
      |> expect(:log, fn _event -> :ok end)

      assert {:ok, :revoked} = RevokeAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - request validation errors" do
    test "returns error when token_id is nil" do
      request = %{valid_request() | token_id: nil}
      deps = build_deps()

      assert {:error, :missing_token_id} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when token_id is empty string" do
      request = %{valid_request() | token_id: ""}
      deps = build_deps()

      assert {:error, :missing_token_id} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when token_id is not a valid UUID" do
      request = %{valid_request() | token_id: "invalid_uuid"}
      deps = build_deps()

      assert {:error, :invalid_token_id} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when organization_id is nil" do
      request = %{valid_request() | organization_id: nil}
      deps = build_deps()

      assert {:error, :missing_organization_id} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when organization_id is empty string" do
      request = %{valid_request() | organization_id: ""}
      deps = build_deps()

      assert {:error, :missing_organization_id} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when revoked_by_user_id is nil" do
      request = %{valid_request() | revoked_by_user_id: nil}
      deps = build_deps()

      assert {:error, :missing_revoked_by_user_id} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when revoked_by_user_id is empty string" do
      request = %{valid_request() | revoked_by_user_id: ""}
      deps = build_deps()

      assert {:error, :missing_revoked_by_user_id} = RevokeAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - token retrieval errors" do
    test "returns error when token not found" do
      request = valid_request()
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:error, :not_found} end)

      assert {:error, :not_found} = RevokeAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - organization validation" do
    test "returns error when token belongs to different organization" do
      request = valid_request()
      # Token with different organization_id
      token = %{build_agent_token() | organization_id: Ecto.UUID.generate()}
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)

      assert {:error, :token_not_found} = RevokeAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - repository errors" do
    test "returns error when revoke fails" do
      request = valid_request()
      token = build_agent_token(request.organization_id)
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)
      |> expect(:revoke, fn _token_id, _reason -> {:error, :database_error} end)

      MockAuditLogger
      |> expect(:log, fn _event -> :ok end)

      assert {:error, :database_error} = RevokeAgentToken.execute(request, deps)
    end

    test "returns error when cascade revoke fails" do
      request = %{valid_request() | cascade: true}
      token = build_agent_token(request.organization_id)
      deps = build_deps()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn _token_id -> {:ok, token} end)
      |> expect(:revoke_delegation_chain, fn _token_id, _reason ->
        {:error, :cascade_failed}
      end)

      MockAuditLogger
      |> expect(:log, fn _event -> :ok end)

      assert {:error, :cascade_failed} = RevokeAgentToken.execute(request, deps)
    end
  end

  # Helper functions

  defp valid_request do
    org_id = Ecto.UUID.generate()

    %{
      token_id: Ecto.UUID.generate(),
      organization_id: org_id,
      revoked_by_user_id: Ecto.UUID.generate(),
      reason: nil,
      cascade: false
    }
  end

  defp build_agent_token(org_id \\ nil) do
    org = org_id || Ecto.UUID.generate()
    {:ok, agent_type} = AgentType.new(:autonomous)
    {:ok, task_id} = TaskId.new(Ecto.UUID.generate())

    {:ok, delegation_chain} =
      DelegationChain.new(%{
        parent_token_id: nil,
        depth: 0,
        path: []
      })

    %AgentToken{
      id: Ecto.UUID.generate(),
      client_id: Ecto.UUID.generate(),
      organization_id: org,
      agent_type: agent_type,
      task_id: task_id,
      task_description: "Test task",
      scopes: ["read:data"],
      delegation_chain: delegation_chain,
      delegator_user_id: Ecto.UUID.generate(),
      expires_in: 3600,
      status: :active,
      revoked_at: nil,
      revoke_reason: nil,
      reason: nil,
      created_at: DateTime.utc_now()
    }
  end

  defp build_deps do
    %{
      agent_token_repository: MockAgentTokenRepository,
      audit_logger: MockAuditLogger
    }
  end

  defp build_deps_with_cache do
    %{
      agent_token_repository: MockAgentTokenRepository,
      audit_logger: MockAuditLogger,
      cache_service: MockCacheService
    }
  end
end
