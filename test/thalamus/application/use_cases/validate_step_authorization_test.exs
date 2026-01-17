defmodule Thalamus.Application.UseCases.ValidateStepAuthorizationTest do
  use ExUnit.Case, async: true

  import Mox

  alias Thalamus.Application.UseCases.ValidateStepAuthorization
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  # Define mocks
  setup :verify_on_exit!

  describe "execute/2" do
    test "validates step successfully with valid token and sufficient scopes" do
      token_string = "at_valid_token_123"
      agent_token = build_agent_token(scopes: ["email:send", "email:read", "calendar:read"])

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:ok, agent_token} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.event_type == "step_authorization.granted"
        assert event.metadata.decision == "granted"
        :ok
      end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send"]
      }

      assert {:ok, response} = ValidateStepAuthorization.execute(request, deps)
      assert response.authorized == true
      assert response.agent_id == agent_token.id
      assert response.agent_type == "autonomous"
      assert response.scopes == ["email:send", "email:read", "calendar:read"]
    end

    test "validates step with multiple required scopes" do
      token_string = "at_valid_token_456"
      agent_token = build_agent_token(scopes: ["email:send", "email:read", "calendar:read"])

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:ok, agent_token} end)

      MockAuditLogger
      |> expect(:log, fn _ -> :ok end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_calendar_invite",
        required_scopes: ["email:send", "calendar:read"]
      }

      assert {:ok, response} = ValidateStepAuthorization.execute(request, deps)
      assert response.authorized == true
    end

    test "returns error when token not found" do
      token_string = "at_nonexistent_token"

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:error, :not_found} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.event_type == "step_authorization.denied"
        assert event.metadata.reason == "token_not_found"
        :ok
      end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send"]
      }

      assert {:error, :token_not_found} = ValidateStepAuthorization.execute(request, deps)
    end

    test "returns error when token is expired" do
      token_string = "at_expired_token"
      # Token expired 1 hour ago
      agent_token = build_agent_token(
        created_at: DateTime.add(DateTime.utc_now(), -7200, :second),
        expires_in: 3600
      )

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:ok, agent_token} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.metadata.reason == "token_expired"
        :ok
      end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send"]
      }

      assert {:error, :token_expired} = ValidateStepAuthorization.execute(request, deps)
    end

    test "returns error when token is revoked" do
      token_string = "at_revoked_token"
      agent_token = build_agent_token(status: :revoked)

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:ok, agent_token} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.metadata.reason == "token_revoked"
        :ok
      end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send"]
      }

      assert {:error, :token_revoked} = ValidateStepAuthorization.execute(request, deps)
    end

    test "returns error when token lacks required scopes" do
      token_string = "at_limited_token"
      agent_token = build_agent_token(scopes: ["email:read"])  # Only read, no send

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:ok, agent_token} end)

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.metadata.reason == "insufficient_scopes"
        :ok
      end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send", "email:read"]  # Requires send, but token only has read
      }

      assert {:error, :insufficient_scopes} = ValidateStepAuthorization.execute(request, deps)
    end

    test "returns error when token format is invalid" do
      token_string = "invalid_token_without_prefix"

      MockAuditLogger
      |> expect(:log, fn event ->
        assert event.event_type == "step_authorization.denied"
        assert event.metadata.reason == "invalid_token_format"
        :ok
      end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send"]
      }

      assert {:error, :invalid_token_format} = ValidateStepAuthorization.execute(request, deps)
    end

    test "accepts workflow context metadata" do
      token_string = "at_valid_token_789"
      agent_token = build_agent_token(scopes: ["email:send"])

      MockAgentTokenRepository
      |> expect(:find_by_access_token, fn ^token_string -> {:ok, agent_token} end)

      MockAuditLogger
      |> expect(:log, fn _ -> :ok end)

      deps = build_deps()

      request = %{
        token: token_string,
        step_name: "send_email",
        required_scopes: ["email:send"],
        workflow_context: %{
          workflow_id: "wf_send_weekly_report",
          execution_id: "exec_123"
        }
      }

      assert {:ok, response} = ValidateStepAuthorization.execute(request, deps)
      assert response.authorized == true
    end
  end

  # Helper functions

  defp build_agent_token(overrides \\ []) do
    {:ok, agent_type} = AgentType.new(:autonomous)
    {:ok, task_id} = TaskId.new(Ecto.UUID.generate())
    {:ok, delegation_chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})

    %AgentToken{
      id: Keyword.get(overrides, :id, Ecto.UUID.generate()),
      client_id: Ecto.UUID.generate(),
      organization_id: Ecto.UUID.generate(),
      agent_type: agent_type,
      task_id: task_id,
      task_description: "Test task",
      scopes: Keyword.get(overrides, :scopes, ["read:data"]),
      delegation_chain: delegation_chain,
      delegator_user_id: Ecto.UUID.generate(),
      expires_in: Keyword.get(overrides, :expires_in, 3600),
      status: Keyword.get(overrides, :status, :active),
      revoked_at: nil,
      revoke_reason: nil,
      reason: nil,
      created_at: Keyword.get(overrides, :created_at, DateTime.utc_now())
    }
  end

  defp build_deps do
    %{
      agent_token_repository: MockAgentTokenRepository,
      audit_logger: MockAuditLogger
    }
  end
end
