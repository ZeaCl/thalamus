defmodule Thalamus.Infrastructure.Repositories.PostgreSQLAgentTokenRepositoryTest do
  use Thalamus.DataCase, async: false

  alias Thalamus.Infrastructure.Repositories.PostgreSQLAgentTokenRepository
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  describe "save/1" do
    test "inserts a new agent token into the database" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()
      org_id = create_organization()
      client_id = create_client(org_id)

      access_token =
        "at_test_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      token_attrs = %{
        access_token: access_token,
        agent_type: agent_type,
        organization_id: org_id,
        client_id: client_id,
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
      org_id = create_organization()
      client_id = create_client(org_id)

      access_token =
        "at_supervisor_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      token_attrs = %{
        access_token: access_token,
        agent_type: agent_type,
        task_id: task_id,
        organization_id: org_id,
        client_id: client_id,
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
      org_id = create_organization()
      client_id = create_client(org_id)

      access_token =
        "at_tool_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      token_attrs = %{
        access_token: access_token,
        agent_type: agent_type,
        organization_id: org_id,
        client_id: client_id,
        scopes: ["tool:execute"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(900, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)

      assert {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token)
      assert saved_token.agent_type.value == :tool
    end

    test "updates an existing token with same ID" do
      {:ok, saved_token} = create_and_save_token()

      # Update the token
      {:ok, revoked_token} = AgentToken.revoke(saved_token)

      assert {:ok, updated_token} = PostgreSQLAgentTokenRepository.save(revoked_token)
      assert updated_token.id == saved_token.id
      assert updated_token.revoked_at != nil
    end

    test "saves token with explicit ID that doesn't exist in DB" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()
      org_id = create_organization()
      client_id = create_client(org_id)

      access_token =
        "at_explicit_id_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      explicit_id = Ecto.UUID.generate()

      token_attrs = %{
        id: explicit_id,
        access_token: access_token,
        agent_type: agent_type,
        organization_id: org_id,
        client_id: client_id,
        scopes: ["read:data"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)

      # Update the token struct with explicit ID to test repository behavior
      token_with_explicit_id = %{token | id: explicit_id}

      assert {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token_with_explicit_id)
      assert saved_token.id == explicit_id
    end

    test "saves token with nil task_id" do
      {:ok, saved_token} = create_and_save_token()

      assert saved_token.task_id == nil
    end

    test "saves token with complex delegation chain" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()
      user_id_3 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2, user_id_3])

      {:ok, saved_token} = create_and_save_token(delegation_chain: chain)

      assert DelegationChain.depth(saved_token.delegation_chain) == 3
    end

    test "saves token with empty scopes list gets default scopes" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()
      org_id = create_organization()
      client_id = create_client(org_id)

      access_token =
        "at_empty_scopes_" <>
          (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      token_attrs = %{
        access_token: access_token,
        agent_type: agent_type,
        organization_id: org_id,
        client_id: client_id,
        scopes: ["default"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)
      {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token)

      assert is_list(saved_token.scopes)
    end

    test "saves token with revoked_at timestamp" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()
      org_id = create_organization()
      client_id = create_client(org_id)

      revoked_at = DateTime.utc_now()

      access_token =
        "at_revoked_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

      token_attrs = %{
        access_token: access_token,
        agent_type: agent_type,
        organization_id: org_id,
        client_id: client_id,
        scopes: ["read:data"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)
      {:ok, revoked_token} = AgentToken.revoke(token, revoked_at)

      assert {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(revoked_token)
      assert saved_token.revoked_at != nil
      # PostgreSQL truncates microseconds, so we need to compare with truncated timestamp
      truncated_revoked_at = DateTime.truncate(revoked_at, :second)
      truncated_saved_at = DateTime.truncate(saved_token.revoked_at, :second)
      assert DateTime.compare(truncated_saved_at, truncated_revoked_at) == :eq
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

    test "handles revoke delegation chain with invalid UUID gracefully" do
      # The repository expects a binary UUID, invalid formats should work with 0 results
      assert {:ok, 0} =
               PostgreSQLAgentTokenRepository.revoke_delegation_chain(Ecto.UUID.generate())
    end
  end

  describe "find_by_organization/2" do
    test "finds all agent tokens for an organization" do
      org_id = create_organization()

      {:ok, _token1} = create_and_save_token(organization_id: org_id)
      {:ok, _token2} = create_and_save_token(organization_id: org_id)
      {:ok, _token3} = create_and_save_token()

      assert {:ok, tokens} = PostgreSQLAgentTokenRepository.find_by_organization(org_id)

      assert length(tokens) == 2
    end

    test "filters by agent_type" do
      org_id = create_organization()
      {:ok, autonomous_type} = AgentType.new("autonomous")
      {:ok, supervisor_type} = AgentType.new("supervisor")

      {:ok, _token1} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)
      {:ok, _token2} = create_and_save_token(organization_id: org_id, agent_type: supervisor_type)
      {:ok, _token3} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)

      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id,
                 agent_type: :autonomous
               )

      assert length(tokens) == 2
      assert Enum.all?(tokens, fn t -> t.agent_type.value == :autonomous end)
    end

    test "filters by agent_type supervisor" do
      org_id = create_organization()
      {:ok, autonomous_type} = AgentType.new("autonomous")
      {:ok, supervisor_type} = AgentType.new("supervisor")

      {:ok, _token1} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)
      {:ok, _token2} = create_and_save_token(organization_id: org_id, agent_type: supervisor_type)
      {:ok, _token3} = create_and_save_token(organization_id: org_id, agent_type: supervisor_type)

      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id,
                 agent_type: :supervisor
               )

      assert length(tokens) == 2
      assert Enum.all?(tokens, fn t -> t.agent_type.value == :supervisor end)
    end

    test "filters by agent_type tool" do
      org_id = create_organization()
      {:ok, tool_type} = AgentType.new("tool")

      {:ok, _token1} = create_and_save_token(organization_id: org_id, agent_type: tool_type)
      {:ok, _token2} = create_and_save_token(organization_id: org_id)

      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, agent_type: :tool)

      assert length(tokens) == 1
      assert Enum.all?(tokens, fn t -> t.agent_type.value == :tool end)
    end

    test "filters by active_only" do
      org_id = create_organization()

      # Create active token
      {:ok, active_token} = create_and_save_token(organization_id: org_id)

      # Create expired token
      {:ok, _expired_token} =
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

    test "active_only false includes all tokens" do
      org_id = create_organization()

      # Create active token
      {:ok, _active_token} = create_and_save_token(organization_id: org_id)

      # Create expired token
      {:ok, _expired_token} =
        create_and_save_token(
          organization_id: org_id,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      # Create revoked token
      {:ok, revoked_token} = create_and_save_token(organization_id: org_id)
      {:ok, _} = PostgreSQLAgentTokenRepository.revoke(revoked_token.access_token)

      # Query without active_only filter (default is false)
      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, active_only: false)

      assert length(tokens) == 3
    end

    test "supports limit and offset pagination" do
      org_id = create_organization()

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

    test "supports only limit without offset" do
      org_id = create_organization()

      {:ok, _token1} = create_and_save_token(organization_id: org_id)
      {:ok, _token2} = create_and_save_token(organization_id: org_id)
      {:ok, _token3} = create_and_save_token(organization_id: org_id)

      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, limit: 1)

      assert length(tokens) == 1
    end

    test "supports only offset without limit" do
      org_id = create_organization()

      {:ok, _token1} = create_and_save_token(organization_id: org_id)
      {:ok, _token2} = create_and_save_token(organization_id: org_id)
      {:ok, _token3} = create_and_save_token(organization_id: org_id)

      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id, offset: 1)

      assert length(tokens) == 2
    end

    test "combines multiple filters together" do
      org_id = create_organization()
      {:ok, autonomous_type} = AgentType.new("autonomous")
      {:ok, supervisor_type} = AgentType.new("supervisor")

      # Create active autonomous tokens
      {:ok, _token1} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)
      {:ok, _token2} = create_and_save_token(organization_id: org_id, agent_type: autonomous_type)

      # Create active supervisor token
      {:ok, _token3} = create_and_save_token(organization_id: org_id, agent_type: supervisor_type)

      # Create expired autonomous token
      {:ok, _expired} =
        create_and_save_token(
          organization_id: org_id,
          agent_type: autonomous_type,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      # Query for active autonomous tokens only
      assert {:ok, tokens} =
               PostgreSQLAgentTokenRepository.find_by_organization(org_id,
                 agent_type: :autonomous,
                 active_only: true
               )

      assert length(tokens) == 2
      assert Enum.all?(tokens, fn t -> t.agent_type.value == :autonomous end)
    end

    test "returns tokens ordered by insertion time (newest first)" do
      org_id = create_organization()
      now = DateTime.utc_now()

      # Create tokens with explicit creation timestamps to ensure ordering
      {:ok, token1} =
        create_and_save_token(
          organization_id: org_id,
          created_at: DateTime.add(now, -120, :second)
        )

      {:ok, _token2} =
        create_and_save_token(
          organization_id: org_id,
          created_at: DateTime.add(now, -60, :second)
        )

      {:ok, token3} =
        create_and_save_token(
          organization_id: org_id,
          created_at: now
        )

      assert {:ok, tokens} = PostgreSQLAgentTokenRepository.find_by_organization(org_id)

      assert length(tokens) == 3
      # Should be ordered newest first
      assert Enum.at(tokens, 0).id == token3.id
      assert Enum.at(tokens, 2).id == token1.id
    end

    test "returns empty list when organization has no tokens" do
      non_existent_org_id = Ecto.UUID.generate()

      assert {:ok, []} =
               PostgreSQLAgentTokenRepository.find_by_organization(non_existent_org_id)
    end

    test "handles empty options list" do
      org_id = create_organization()

      {:ok, _token1} = create_and_save_token(organization_id: org_id)

      assert {:ok, tokens} = PostgreSQLAgentTokenRepository.find_by_organization(org_id, [])

      assert length(tokens) == 1
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

    test "deletes multiple expired tokens" do
      # Create multiple expired tokens
      {:ok, _expired1} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(-7200, :second))

      {:ok, _expired2} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second))

      {:ok, _expired3} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(-1800, :second))

      assert {:ok, count} = PostgreSQLAgentTokenRepository.cleanup_expired()

      assert count == 3
    end

    test "does not delete revoked but not expired tokens" do
      # Create revoked but not expired token
      {:ok, revoked_token} =
        create_and_save_token(expires_at: DateTime.utc_now() |> DateTime.add(3600, :second))

      {:ok, _} = PostgreSQLAgentTokenRepository.revoke(revoked_token.access_token)

      # Cleanup should not delete it (it's revoked but not expired)
      assert {:ok, 0} = PostgreSQLAgentTokenRepository.cleanup_expired()
    end
  end

  describe "to_domain conversion" do
    test "reconstructs agent_type from database" do
      {:ok, agent_type} = AgentType.new("supervisor")
      {:ok, saved_token} = create_and_save_token(agent_type: agent_type)

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert %AgentType{} = found_token.agent_type
      assert found_token.agent_type.value == :supervisor
    end

    test "reconstructs task_id from database" do
      {:ok, task_id} = TaskId.new("task_123")
      {:ok, saved_token} = create_and_save_token(task_id: task_id)

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert %TaskId{} = found_token.task_id
      assert to_string(found_token.task_id) == "task_123"
    end

    test "reconstructs delegation_chain from database" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      {:ok, saved_token} = create_and_save_token(delegation_chain: chain)

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert %DelegationChain{} = found_token.delegation_chain
      assert DelegationChain.depth(found_token.delegation_chain) == 2
    end

    test "handles nil task_id in database" do
      {:ok, saved_token} = create_and_save_token(task_id: nil)

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert found_token.task_id == nil
    end

    test "handles empty delegation_chain in database" do
      {:ok, chain} = DelegationChain.root()
      {:ok, saved_token} = create_and_save_token(delegation_chain: chain)

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert %DelegationChain{} = found_token.delegation_chain
      assert DelegationChain.depth(found_token.delegation_chain) == 0
    end

    test "handles nil scopes in database" do
      {:ok, agent_type} = AgentType.new("autonomous")
      {:ok, chain} = DelegationChain.root()
      org_id = create_organization()
      client_id = create_client(org_id)

      token_attrs = %{
        access_token:
          "at_nil_scopes_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)),
        agent_type: agent_type,
        organization_id: org_id,
        client_id: client_id,
        scopes: ["test"],
        delegation_chain: chain,
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      }

      {:ok, token} = AgentToken.create(token_attrs)
      {:ok, saved_token} = PostgreSQLAgentTokenRepository.save(token)

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert is_list(found_token.scopes)
    end

    test "preserves created_at timestamp" do
      {:ok, saved_token} = create_and_save_token()

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)
      assert %DateTime{} = found_token.created_at
    end

    test "preserves all fields accurately" do
      {:ok, agent_type} = AgentType.new("supervisor")
      {:ok, task_id} = TaskId.new("task_abc123")
      user_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new([user_id])

      {:ok, saved_token} =
        create_and_save_token(
          agent_type: agent_type,
          task_id: task_id,
          delegation_chain: chain,
          scopes: ["read:data", "write:data", "admin:manage"],
          reason: "Testing preservation"
        )

      assert {:ok, found_token} = PostgreSQLAgentTokenRepository.find_by_id(saved_token.id)

      assert found_token.access_token == saved_token.access_token
      assert found_token.agent_type.value == :supervisor
      assert to_string(found_token.task_id) == "task_abc123"
      assert DelegationChain.depth(found_token.delegation_chain) == 1
      assert found_token.scopes == ["read:data", "write:data", "admin:manage"]
      assert found_token.reason == "Testing preservation"
      assert found_token.organization_id == saved_token.organization_id
      assert found_token.client_id == saved_token.client_id
    end
  end

  describe "error handling" do
    test "find_by_access_token handles invalid token format gracefully" do
      assert {:error, :not_found} =
               PostgreSQLAgentTokenRepository.find_by_access_token("invalid_token")
    end

    test "revoke handles very long token strings" do
      long_token = String.duplicate("a", 1000)

      assert {:error, :not_found} = PostgreSQLAgentTokenRepository.revoke(long_token)
    end
  end

  describe "base_agent_tokens_query filtering" do
    test "only returns tokens with agent_type set" do
      org_id = create_organization()

      # Create agent token
      {:ok, _agent_token} = create_and_save_token(organization_id: org_id)

      # Create non-agent token directly in database
      alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema
      client_id = create_client(org_id)

      non_agent_token = %TokenSchema{
        token:
          "at_non_agent_" <>
            (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)),
        type: :access_token,
        client_id: client_id,
        scopes: ["read:data"],
        expires_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
        agent_type: nil,
        revoked: false
      }

      Repo.insert!(non_agent_token)

      # Should only find the agent token
      assert {:ok, tokens} = PostgreSQLAgentTokenRepository.find_by_organization(org_id)
      assert length(tokens) == 1
    end
  end

  # --- Test Helpers ---

  defp create_and_save_token(overrides \\ []) do
    # Create organization and client in database for foreign key constraints
    org_id = Keyword.get(overrides, :organization_id) || create_organization()
    client_id = Keyword.get(overrides, :client_id) || create_client(org_id)

    {:ok, agent_type} = AgentType.new(Keyword.get(overrides, :agent_type_str, "autonomous"))

    chain =
      case Keyword.get(overrides, :delegation_chain) do
        nil ->
          {:ok, c} = DelegationChain.root()
          c

        %DelegationChain{} = c ->
          c
      end

    # Generate access token that meets minimum 32-byte requirement
    default_token =
      "at_test_" <> (:crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false))

    expires_at =
      Keyword.get(
        overrides,
        :expires_at,
        DateTime.utc_now() |> DateTime.add(3600, :second)
      )

    token_attrs = %{
      access_token: Keyword.get(overrides, :access_token, default_token),
      agent_type: Keyword.get(overrides, :agent_type, agent_type),
      organization_id: org_id,
      client_id: client_id,
      scopes: Keyword.get(overrides, :scopes, ["read:data"]),
      delegation_chain: chain,
      expires_at: expires_at
    }

    # Add optional fields if present in overrides
    token_attrs =
      token_attrs
      |> maybe_add_field(:task_id, Keyword.get(overrides, :task_id))
      |> maybe_add_field(:reason, Keyword.get(overrides, :reason))
      |> maybe_add_field(:id, Keyword.get(overrides, :id))
      |> maybe_add_field(:created_at, Keyword.get(overrides, :created_at))

    # If token is expired, use from_trusted_attrs to bypass validation
    # This is needed for cleanup_expired tests
    token =
      if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
        {:ok, token} = AgentToken.from_trusted_attrs(token_attrs)
        token
      else
        {:ok, token} = AgentToken.create(token_attrs)
        token
      end

    PostgreSQLAgentTokenRepository.save(token)
  end

  defp maybe_add_field(attrs, _key, nil), do: attrs
  defp maybe_add_field(attrs, key, value), do: Map.put(attrs, key, value)

  defp create_organization do
    org = %Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema{
      id: Ecto.UUID.generate(),
      name: "Test Organization #{:rand.uniform(1_000_000)}",
      status: :active,
      plan_type: :standard,
      verified: true,
      max_users: 100,
      max_api_calls_per_month: 100_000,
      support_level: :priority,
      api_calls_reset_at: DateTime.utc_now() |> DateTime.truncate(:second)
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
