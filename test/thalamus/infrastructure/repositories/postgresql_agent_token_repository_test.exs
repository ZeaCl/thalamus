defmodule Thalamus.Infrastructure.Repositories.PostgreSQLAgentTokenRepositoryTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Infrastructure.Repositories.PostgreSQLAgentTokenRepository
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  describe "save/1" do
    test "inserts a new agent token into the database" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()

      token_attrs = %{
        access_token: "at_test_#{:rand.uniform(1_000_000)}",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["read:data", "write:data"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)

      assert {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token)
      assert saved_token.id != nil
      assert saved_token.access_token == token.access_token
      assert saved_token.agent_type.value == :autonomous
      assert saved_token.scopes == ["read:data", "write:data"]
      assert saved_token.organization_id == token.organization_id
      assert saved_token.client_id == token.client_id
    end

    test "saves a supervisor agent token with task_id and reason" do
      {:ok, agent_type} = AgentType.new("supervisor")
      {:ok, task_id} = TaskId.new(Ecto.UUID.generate())
      {:ok, chain} = DelegationChain.root()

      token_attrs = %{
        access_token: "at_supervisor_#{:rand.uniform(1_000_000)}",
        agent_type: agent_type,
        task_id: task_id,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["supervisor:manage"],
        delegation_chain: chain,
        reason: "Coordinating sub-agents",
        expires_at: DateTime.utc_now() |> DateTime.add(1800, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)

      assert {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token)
      assert saved_token.task_id != nil
      assert saved_token.reason == "Coordinating sub-agents"
      assert saved_token.agent_type.value == :supervisor
    end

    test "saves a tool agent token" do
      {:ok, agent_type} = AgentType.new("tool")
      {:ok, chain} = DelegationChain.root()

      token_attrs = %{
        access_token: "at_tool_#{:rand.uniform(1_000_000)}",
        agent_type: agent_type,
        organization_id: Ecto.UUID.generate(),
        client_id: Ecto.UUID.generate(),
        scopes: ["tool:execute"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)

      assert {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token)
      assert saved_token.agent_type.value == :tool
    end
  end

  describe "find_by_id/1" do
    test "finds a token by its ID" do
      {:ok, saved_token} = create_and_save_token()

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert found_token.id == saved_token.id
      assert found_token.access_token == saved_token.access_token
      assert found_token.agent_type.value == saved_token.agent_type.value
    end

    test "returns :not_found when token does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = PostgreSQLAgentTokenRepository.find_by_id(non_existent_id)
    end
  end

  describe "find_by_access_token/1" do
    test "finds a non-revoked token by access token value" do
      {:ok, saved_token} = create_and_save_token()

      assert {:ok, found_token} =
               PostgreSQLAgentTokenRepository.find_by_access_token(saved_token.access_token)

      assert found_token.id == saved_token.id
      assert found_token.access_token == saved_token.access_token
    end

    test "returns :not_found when token does not exist" do
      assert {:error, :not_found} =
               PostgreSQLAgentTokenRepository.find_by_access_token("at_nonexistent")
    end

    test "returns :not_found for revoked tokens" do
      {:ok, saved_token} = create_and_save_token()

      # Revoke the token
      {:ok, _revoked} = PostgreSQLAgentTokenRepository.revoke(saved_token.access_token)

      # Should not find revoked token
      assert {:error, :not_found} =
               PostgreSQLAgentTokenRepository.find_by_access_token(saved_token.access_token)
    end
  end

  describe "revoke/1" do
    test "revokes a token by access token value" do
      {:ok, saved_token} = create_and_save_token()

      assert saved_token.revoked_at == nil

      assert {:ok, revoked_token} =
               PostgreSQLAgentTokenRepository.revoke(saved_token.access_token)

      assert revoked_token.revoked_at != nil
      assert %DateTime{} = revoked_token.revoked_at
    end

    test "returns :not_found when revoking non-existent token" do
      assert {:error, :not_found} =
               PostgreSQLAgentTokenRepository.revoke("at_nonexistent_token")
    end
  end

  describe "revoke_delegation_chain/1" do
    test "revokes all tokens in a delegation chain" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      # Create tokens with different delegation chains
      {:ok, chain_1} = DelegationChain.new([user_id_1])
      {:ok, chain_2} = DelegationChain.new([user_id_1, user_id_2])
      {:ok, chain_3} = DelegationChain.new([user_id_2])

      {:ok, _token1} = create_and_save_token(delegation_chain: chain_1)
      {:ok, _token2} = create_and_save_token(delegation_chain: chain_2)
      {:ok, _token3} = create_and_save_token(delegation_chain: chain_3)

      # Revoke all tokens in user_id_1's delegation chain
      assert {:ok, count} = PostgreSQLAgentTokenRepository.revoke_delegation_chain(user_id_1)

      # Should have revoked 2 tokens (token1 and token2)
      assert count == 2
    end

    test "returns 0 when no tokens match the delegation chain" do
      non_existent_user_id = Ecto.UUID.generate()

      assert {:ok, 0} =
               PostgreSQLAgentTokenRepository.revoke_delegation_chain(non_existent_user_id)
    end
  end

  describe "find_by_organization/2" do
    test "finds all agent tokens for an organization" do
      org_id = Ecto.UUID.generate()

      {:ok, _token1} = create_and_save_token(organization_id: org_id)
      {:ok, _token2} = create_and_save_token(organization_id: org_id)
      {:ok, _token3} = create_and_save_token(organization_id: Ecto.UUID.generate())

      assert {:ok, tokens} = PostgreSQLAgentTokenRepository.find_by_organization(org_id)

      assert length(tokens) == 2
    end

    test "filters by agent_type" do
      org_id = Ecto.UUID.generate()
      {:ok, autonomous_type} = AgentType.new("autonomous")
      {:ok, supervisor_type} = AgentType.new("supervisor")

      {:ok, _token1} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)
      {:ok, _token2} = create_and_save_token(organization_id: org_id, agent_type: supervisor_type)
      {:ok, _token3} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)

      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, agent_type: :autonomous)

      assert length(tokens) == 2
      assert Enum.all?(tokens, fn t -> t.agent_type.value == :autonomous end)
    end

    test "filters by active_only" do
      org_id = Ecto.UUID.generate()

      # Create active token
      {:ok, active_token} = create_and_save_token(organization_id: org_id)

      # Create expired token
      {:ok, expired_token} =
        create_and_save_token(
          organization_id: org_id,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      # Create revoked token
      {:ok, revoked_token} = create_and_save_token(organization_id: org_id)
      {:ok, _} = PostgreSQLAgentTokenRepository.revoke(revoked_token.access_token)

      # Query for active only
      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, active_only: true)

      assert length(tokens) == 1
      assert hd(tokens).id == active_token.id
    end

    test "supports limit and offset pagination" do
      org_id = Ecto.UUID.generate()

      {:ok, _token1} = create_and_save_token(organization_id: org_id)
      {:ok, _token2} = create_and_save_token(organization_id: org_id)
      {:ok, _token3} = create_and_save_token(organization_id: org_id)

      # Get first 2
      assert {:ok, page1} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, limit: 2, offset: 0)

      assert length(page1) == 2

      # Get next 1
      assert {:ok, page2} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, limit: 2, offset: 2)

      assert length(page2) == 1
    end

    test "returns empty list when organization has no tokens" do
      non_existent_org_id = Ecto.UUID.generate()

      assert {:ok, []} =
               PostgreSQLAgentTokenRepository.find_by_organization(non_existent_org_id)
    end
  end

  describe "cleanup_expired/0" do
    test "deletes expired agent tokens" do
      # Create expired token
      {:ok, _expired_token} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second))

      # Create active token
      {:ok, active_token} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(3600, :second))

      assert {:ok, count} = PostgreSQLAgentTokenRepository.cleanup_expired()

      assert count == 1

      # Verify active token still exists
      assert {:ok, _} = PostgreSQLAgentTokenRepository.find_by_id(active_token.id)
    end

    test "returns 0 when no expired tokens exist" do
      {:ok, _active_token} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(3600, :second))

      assert {:ok, 0} = PostgreSQLAgentTokenRepository.cleanup_expired()
    end
  end

  # --- Test Helpers ---

  defp create_and_save_token(overrides \\ []) do
    # Create organization and client in database for foreign key constraints
    org_id = Keyword.get(overrides, :organization_id) || create_organization()
    client_id = Keyword.get(overrides, :client_id) || create_client(org_id)

    {:ok, agent_type} = AgentType.new(Keyword.get(overrides, :agent_type_str, "autonomous"))
    {:ok, chain} = Keyword.get(overrides, :delegation_chain) || DelegationChain.root()

    token_attrs = %{
      access_token: Keyword.get(overrides, :access_token, "at_test_#{:rand.uniform(1_000_000)}"),
      agent_type: Keyword.get(overrides, :agent_type, agent_type),
      organization_id: org_id,
      client_id: client_id,
      scopes: Keyword.get(overrides, :scopes, ["read:data"]),
      delegation_chain: chain,
      expires_at:
        Keyword.get(
          overrides,
          :expires_at,
          DateTime.utc_now() |> DateTime.add(3600, :second)
        )
    }

    {:ok, token} = AgentToken.create(token_attrs)
    PostgreSQLAgentTokenRepository.save(token)
  end

  defp create_organization do
    org = %Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Test Organization #{:rand.uniform(1_000_000)}",
      status: :active,
      plan_type: :professional,
      verified: true,
      max_users: 100,
      max_api_calls_per_month: 100_000,
      support_level: :priority,
      api_calls_reset_at: DateTime.utc_now()
    }

    Repo.insert!(org)
    org.id
  end

  defp create_client(org_id) do
    client = %Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema{
      id: Ecto.UUID.generate(),
      client_id_string: Ecto.UUID.generate(),
      client_secret: Bcrypt.hash_pwd_salt("test_secret"),
      name: "Test Client",
      client_type: :confidential,
      organization_id: org_id,
      redirect_uris: ["http://localhost:3000/callback"],
      allowed_scopes: ["read:data", "write:data", "supervisor:manage", "tool:execute"],
      allowed_grant_types: ["authorization_code", "client_credentials"],
      is_active: true
    }

    Repo.insert!(client)
    client.id
  end
end
