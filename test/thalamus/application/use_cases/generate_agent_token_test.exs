defmodule Thalamus.Application.UseCases.GenerateAgentTokenTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.UseCases.GenerateAgentToken
  alias Thalamus.Application.DTOs.{AgentTokenRequest, AgentTokenResponse}
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  # Setup Mox to verify expectations
  setup :verify_on_exit!

  describe "execute/2 - happy path" do
    test "generates agent token successfully" do
      request = valid_request()
      deps = setup_successful_mocks(request.organization_id)

      assert {:ok, %AgentTokenResponse{} = response} = GenerateAgentToken.execute(request, deps)

      assert response.token_type == "Bearer"
      assert response.expires_in == 3600
      assert response.scope == "read:data write:results"
      assert response.agent_type == "autonomous"
      assert is_binary(response.task_id)
      assert response.task_description == "Test task"
      assert response.delegation_depth == 0
    end

    test "generates token with custom TTL" do
      request = %{valid_request() | expires_in: 1800}
      deps = setup_successful_mocks(request.organization_id)

      assert {:ok, %AgentTokenResponse{} = response} = GenerateAgentToken.execute(request, deps)
      assert response.expires_in == 1800
    end

    test "generates token with provided task_id" do
      task_id = Ecto.UUID.generate()
      request = %{valid_request() | task_id: task_id}
      deps = setup_successful_mocks(request.organization_id)

      assert {:ok, %AgentTokenResponse{} = response} = GenerateAgentToken.execute(request, deps)
      assert response.task_id == task_id
    end

    test "generates token with reason" do
      request = %{valid_request() | reason: "Automated processing"}
      deps = setup_successful_mocks(request.organization_id)

      assert {:ok, %AgentTokenResponse{}} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - request validation errors" do
    test "returns error when client_id is missing" do
      request = %{valid_request() | client_id: nil}
      deps = build_deps()

      assert {:error, :missing_client_id} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when client_secret is missing" do
      request = %{valid_request() | client_secret: nil}
      deps = build_deps()

      assert {:error, :missing_client_secret} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when organization_id is missing" do
      request = %{valid_request() | organization_id: nil}
      deps = build_deps()

      assert {:error, :missing_organization_id} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when delegator_user_id is missing" do
      request = %{valid_request() | delegator_user_id: nil}
      deps = build_deps()

      assert {:error, :missing_delegator_user_id} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when agent_type is invalid" do
      request = %{valid_request() | agent_type: "invalid_type"}
      deps = build_deps()

      assert {:error, :invalid_agent_type} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when task_description is missing" do
      request = %{valid_request() | task_description: nil}
      deps = build_deps()

      assert {:error, :missing_task_description} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when scopes is empty" do
      request = %{valid_request() | scopes: []}
      deps = build_deps()

      assert {:error, :empty_scopes} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - client authentication errors" do
    test "returns error when client not found" do
      request = valid_request()

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _client_id ->
        {:error, :not_found}
      end)

      deps = build_deps()

      assert {:error, :invalid_client_credentials} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when client is inactive" do
      request = valid_request()
      client = %{build_client(request.organization_id) | is_active: false}

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _client_id ->
        {:ok, client}
      end)

      deps = build_deps()

      assert {:error, :client_inactive} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when client secret is invalid" do
      request = %{valid_request() | client_secret: "wrong_secret"}
      client = build_client(request.organization_id)

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _client_id ->
        {:ok, client}
      end)

      deps = build_deps()

      assert {:error, :invalid_client_credentials} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when organization mismatch" do
      request = valid_request()
      client = %{build_client(request.organization_id) | organization_id: Ecto.UUID.generate()}

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _client_id ->
        {:ok, client}
      end)

      deps = build_deps()

      assert {:error, :organization_mismatch} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - user validation errors" do
    test "returns error when user not found" do
      request = valid_request()
      deps = build_deps()

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, build_client(request.organization_id)} end)

      MockUserRepository
      |> expect(:find_by_id, fn _user_id -> {:error, :not_found} end)

      assert {:error, :delegator_not_found} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when user is not active" do
      request = valid_request()
      user = %{build_user(request.organization_id) | status: :suspended}

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, build_client(request.organization_id)} end)

      MockUserRepository
      |> expect(:find_by_id, fn _ -> {:ok, user} end)

      deps = build_deps()

      assert {:error, :delegator_not_active} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when user organization mismatch" do
      request = valid_request()
      user = %{build_user(request.organization_id) | organization_id: Ecto.UUID.generate()}

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, build_client(request.organization_id)} end)

      MockUserRepository
      |> expect(:find_by_id, fn _ -> {:ok, user} end)

      deps = build_deps()

      assert {:error, :delegator_organization_mismatch} =
               GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - scope validation" do
    test "returns error when requested scopes not subset of allowed scopes" do
      request = %{valid_request() | scopes: ["admin:write", "delete:all"]}
      client = build_client(request.organization_id)

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, client} end)

      MockUserRepository
      |> expect(:find_by_id, fn _ -> {:ok, build_user(request.organization_id)} end)

      deps = build_deps()

      assert {:error, :invalid_scopes} = GenerateAgentToken.execute(request, deps)
    end
  end

  describe "execute/2 - delegation chain" do
    test "creates root token when no parent_agent_id" do
      request = valid_request()
      deps = setup_successful_mocks(request.organization_id)

      assert {:ok, response} = GenerateAgentToken.execute(request, deps)
      assert response.delegation_depth == 0
    end

    test "creates child token with valid parent" do
      parent_id = Ecto.UUID.generate()
      # Child TTL must be less than parent's remaining TTL
      request = %{valid_request() | parent_agent_id: parent_id, expires_in: 1800}

      # Parent must have all scopes that child will request (scope narrowing)
      parent_token = build_saved_agent_token(%{
        id: parent_id,
        delegation_depth: 0,
        scopes: ["read:data", "write:results"]  # Include all child scopes
      })

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, build_client(request.organization_id)} end)

      MockUserRepository
      |> expect(:find_by_id, fn _ -> {:ok, build_user(request.organization_id)} end)

      MockAgentTokenRepository
      |> expect(:find_by_id, 2, fn ^parent_id -> {:ok, parent_token} end)  # Called twice: scope validation + delegation chain
      |> expect(:save, fn token -> {:ok, token} end)

      MockAuditLogger
      |> expect(:log, fn _ -> :ok end)

      deps = build_deps()

      assert {:ok, response} = GenerateAgentToken.execute(request, deps)
      assert response.delegation_depth == 1
    end

    test "returns error when parent token not found" do
      parent_id = Ecto.UUID.generate()
      request = %{valid_request() | parent_agent_id: parent_id}

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, build_client(request.organization_id)} end)

      MockUserRepository
      |> expect(:find_by_id, fn _ -> {:ok, build_user(request.organization_id)} end)

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id -> {:error, :not_found} end)

      deps = build_deps()

      assert {:error, :parent_token_not_found} = GenerateAgentToken.execute(request, deps)
    end

    test "returns error when parent token is not active" do
      parent_id = Ecto.UUID.generate()
      request = %{valid_request() | parent_agent_id: parent_id}

      # Parent must have required scopes even if revoked (scope check happens before status check)
      parent_token = build_saved_agent_token(%{
        id: parent_id,
        status: :revoked,
        scopes: ["read:data", "write:results"]
      })

      MockOAuth2ClientRepository
      |> expect(:find_by_client_id, fn _ -> {:ok, build_client(request.organization_id)} end)

      MockUserRepository
      |> expect(:find_by_id, fn _ -> {:ok, build_user(request.organization_id)} end)

      MockAgentTokenRepository
      |> expect(:find_by_id, 2, fn ^parent_id -> {:ok, parent_token} end)  # Called twice: scope validation + delegation chain

      deps = build_deps()

      assert {:error, :parent_token_not_active} = GenerateAgentToken.execute(request, deps)
    end
  end

  # Helper functions

  defp valid_request do
    org_id = Ecto.UUID.generate()

    %AgentTokenRequest{
      client_id: "client_123",
      client_secret: "secret_password",
      organization_id: org_id,
      delegator_user_id: Ecto.UUID.generate(),
      agent_type: "autonomous",
      task_id: nil,
      task_description: "Test task",
      scopes: ["read:data", "write:results"],
      parent_agent_id: nil,
      expires_in: 3600,
      reason: nil
    }
  end

  defp build_client(org_id \\ nil) do
    org = org_id || Ecto.UUID.generate()

    %{
      id: Ecto.UUID.generate(),
      client_id_string: "client_123",
      organization_id: org,
      client_secret: Bcrypt.hash_pwd_salt("secret_password"),
      is_active: true,
      allowed_scopes: ["read:data", "write:results", "admin:read"]
    }
  end

  defp build_user(org_id \\ nil) do
    org = org_id || Ecto.UUID.generate()

    %{
      id: Ecto.UUID.generate(),
      organization_id: org,
      status: :active
    }
  end

  defp build_saved_agent_token(overrides \\ %{}) do
    {:ok, agent_type} = AgentType.new(:autonomous)
    {:ok, task_id} = TaskId.new(Ecto.UUID.generate())

    {:ok, delegation_chain} =
      DelegationChain.new(%{
        parent_token_id: Map.get(overrides, :parent_token_id),
        depth: Map.get(overrides, :delegation_depth, 0),
        path: Map.get(overrides, :path, [])
      })

    %AgentToken{
      id: Map.get(overrides, :id, Ecto.UUID.generate()),
      client_id: Ecto.UUID.generate(),
      organization_id: Ecto.UUID.generate(),
      agent_type: agent_type,
      task_id: task_id,
      task_description: "Test task",
      scopes: Map.get(overrides, :scopes, ["read:data"]),
      delegation_chain: delegation_chain,
      delegator_user_id: Ecto.UUID.generate(),
      expires_in: 3600,
      status: Map.get(overrides, :status, :active),
      revoked_at: nil,
      revoke_reason: nil,
      reason: nil,
      created_at: DateTime.utc_now()
    }
  end

  defp build_deps do
    %{
      client_repository: MockOAuth2ClientRepository,
      user_repository: MockUserRepository,
      agent_token_repository: MockAgentTokenRepository,
      audit_logger: MockAuditLogger
    }
  end

  defp setup_successful_mocks(org_id \\ nil) do
    client = build_client(org_id)
    user = %{build_user(org_id) | organization_id: client.organization_id}

    MockOAuth2ClientRepository
    |> expect(:find_by_client_id, fn _client_id ->
      {:ok, client}
    end)

    MockUserRepository
    |> expect(:find_by_id, fn _user_id ->
      {:ok, user}
    end)

    MockAgentTokenRepository
    |> expect(:save, fn token ->
      {:ok, token}
    end)

    MockAuditLogger
    |> expect(:log, fn _event ->
      :ok
    end)

    build_deps()
  end
end
