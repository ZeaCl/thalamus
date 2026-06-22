defmodule Thalamus.Infrastructure.Repositories.PostgresqlAgentTokenRepositoryTest do
  use Thalamus.DataCase, async: true

  alias Thalamus.Infrastructure.Repositories.PostgresqlAgentTokenRepository
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  alias Thalamus.Infrastructure.Persistence.Schemas.{
    AgentTokenSchema,
    OAuth2ClientSchema,
    OrganizationSchema,
    UserSchema
  }

  alias Thalamus.Repo

  describe "save/1 - creating new tokens" do
    test "creates new agent token successfully" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)

      assert {:ok, saved_token} = PostgresqlAgentTokenRepository.save(token)

      # Verify domain entity returned
      assert %AgentToken{} = saved_token
      assert saved_token.id == token.id
      assert saved_token.client_id == client.id
      assert saved_token.organization_id == "org_" <> org.id
      assert saved_token.agent_type == token.agent_type
      assert saved_token.task_id == token.task_id
      assert saved_token.task_description == token.task_description
      assert saved_token.scopes == token.scopes
      assert saved_token.delegation_chain.depth == 0
      assert saved_token.delegator_user_id == user.id
      assert saved_token.status == :active
      assert is_nil(saved_token.revoked_at)

      # Verify database record
      schema = Repo.get(AgentTokenSchema, token.id)
      assert schema.client_id == client.id
      assert schema.organization_id == org.id
      assert schema.agent_type == "autonomous"
      assert schema.delegation_depth == 0
    end

    test "creates token with parent delegation" do
      {client, org, user} = setup_dependencies()
      parent_token = build_agent_token(client.id, org.id, user.id)
      {:ok, _saved_parent} = PostgresqlAgentTokenRepository.save(parent_token)

      # Create child token
      {:ok, delegation_chain} =
        DelegationChain.new(%{
          parent_token_id: parent_token.id,
          depth: 1,
          path: [parent_token.id]
        })

      child_token =
        build_agent_token(client.id, org.id, user.id, %{delegation_chain: delegation_chain})

      assert {:ok, saved_child} = PostgresqlAgentTokenRepository.save(child_token)

      assert saved_child.delegation_chain.parent_token_id == parent_token.id
      assert saved_child.delegation_chain.depth == 1
      assert saved_child.delegation_chain.path == [parent_token.id]

      # Verify database
      schema = Repo.get(AgentTokenSchema, child_token.id)
      assert schema.parent_agent_id == parent_token.id
      assert schema.delegation_depth == 1
      assert schema.delegation_chain["parent_token_id"] == parent_token.id
      assert schema.delegation_chain["path"] == [parent_token.id]
    end

    test "generates unique access tokens" do
      {client, org, user} = setup_dependencies()
      token1 = build_agent_token(client.id, org.id, user.id)
      token2 = build_agent_token(client.id, org.id, user.id)

      {:ok, saved1} = PostgresqlAgentTokenRepository.save(token1)
      {:ok, saved2} = PostgresqlAgentTokenRepository.save(token2)

      # Verify unique access tokens generated
      schema1 = Repo.get(AgentTokenSchema, saved1.id)
      schema2 = Repo.get(AgentTokenSchema, saved2.id)

      assert schema1.access_token != schema2.access_token
      assert byte_size(schema1.access_token) > 40
      assert byte_size(schema2.access_token) > 40
    end

    test "fails with invalid foreign key" do
      fake_client_id = Ecto.UUID.generate()
      fake_org_id = Ecto.UUID.generate()
      fake_user_id = Ecto.UUID.generate()

      token = build_agent_token(fake_client_id, fake_org_id, fake_user_id)

      assert {:error, changeset} = PostgresqlAgentTokenRepository.save(token)
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
    end
  end

  describe "save/1 - updating existing tokens" do
    test "updates existing token when saved again" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)

      # Save first time
      {:ok, saved_token} = PostgresqlAgentTokenRepository.save(token)

      # Revoke the token
      {:ok, revoked_token} = AgentToken.revoke(saved_token, "Manual revocation")

      # Save again (update)
      assert {:ok, updated_token} = PostgresqlAgentTokenRepository.save(revoked_token)

      assert updated_token.status == :revoked
      assert updated_token.revoke_reason == "Manual revocation"
      assert not is_nil(updated_token.revoked_at)

      # Verify in database
      schema = Repo.get(AgentTokenSchema, token.id)
      assert not is_nil(schema.revoked_at)
      assert schema.revoke_reason == "Manual revocation"
    end
  end

  describe "find_by_id/1" do
    test "finds token by ID successfully" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, _saved} = PostgresqlAgentTokenRepository.save(token)

      assert {:ok, found_token} = PostgresqlAgentTokenRepository.find_by_id(token.id)

      assert %AgentToken{} = found_token
      assert found_token.id == token.id
      assert found_token.client_id == client.id
      assert found_token.organization_id == "org_" <> org.id
      assert found_token.status == :active
    end

    test "returns error when token not found" do
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} = PostgresqlAgentTokenRepository.find_by_id(fake_id)
    end

    test "returns token even if revoked" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

      # Revoke it
      PostgresqlAgentTokenRepository.revoke(saved.id, "Test")

      # Should still find it
      assert {:ok, found} = PostgresqlAgentTokenRepository.find_by_id(token.id)
      assert found.status == :revoked
    end
  end

  describe "find_by_access_token/1" do
    test "finds token by access token successfully" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

      # Get the generated access token from database
      schema = Repo.get(AgentTokenSchema, saved.id)

      assert {:ok, found_token} =
               PostgresqlAgentTokenRepository.find_by_access_token(schema.access_token)

      assert %AgentToken{} = found_token
      assert found_token.id == token.id
      assert found_token.client_id == client.id
    end

    test "returns error when access token not found" do
      fake_token = "invalid_access_token_12345678901234567890"

      assert {:error, :not_found} =
               PostgresqlAgentTokenRepository.find_by_access_token(fake_token)
    end

    test "does not find revoked tokens" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

      # Get access token
      schema = Repo.get(AgentTokenSchema, saved.id)
      access_token = schema.access_token

      # Revoke the token
      PostgresqlAgentTokenRepository.revoke(saved.id, "Revoked")

      # Should not find revoked token
      assert {:error, :not_found} =
               PostgresqlAgentTokenRepository.find_by_access_token(access_token)
    end
  end

  describe "find_by_organization/2" do
    test "finds all active tokens for organization" do
      {client, org, user} = setup_dependencies()

      # Create 3 tokens for this org
      token1 = build_agent_token(client.id, org.id, user.id)
      token2 = build_agent_token(client.id, org.id, user.id)
      token3 = build_agent_token(client.id, org.id, user.id)

      {:ok, _} = PostgresqlAgentTokenRepository.save(token1)
      {:ok, _} = PostgresqlAgentTokenRepository.save(token2)
      {:ok, _} = PostgresqlAgentTokenRepository.save(token3)

      assert {:ok, tokens} = PostgresqlAgentTokenRepository.find_by_organization(org.id)

      assert length(tokens) == 3
      assert Enum.all?(tokens, &(&1.organization_id == "org_" <> org.id))
      assert Enum.all?(tokens, &(&1.status == :active))
    end

    test "respects limit parameter" do
      {client, org, user} = setup_dependencies()

      # Create 5 tokens
      for _ <- 1..5 do
        token = build_agent_token(client.id, org.id, user.id)
        PostgresqlAgentTokenRepository.save(token)
      end

      assert {:ok, tokens} = PostgresqlAgentTokenRepository.find_by_organization(org.id, limit: 2)

      assert length(tokens) == 2
    end

    test "respects offset parameter" do
      {client, org, user} = setup_dependencies()

      # Create 5 tokens
      for _ <- 1..5 do
        token = build_agent_token(client.id, org.id, user.id)
        PostgresqlAgentTokenRepository.save(token)
      end

      # Get first 3
      {:ok, batch1} =
        PostgresqlAgentTokenRepository.find_by_organization(org.id, limit: 3, offset: 0)

      # Get next 2
      {:ok, batch2} =
        PostgresqlAgentTokenRepository.find_by_organization(org.id, limit: 3, offset: 3)

      assert length(batch1) == 3
      assert length(batch2) == 2

      # Verify no overlap
      ids1 = Enum.map(batch1, & &1.id)
      ids2 = Enum.map(batch2, & &1.id)
      assert MapSet.disjoint?(MapSet.new(ids1), MapSet.new(ids2))
    end

    test "excludes revoked tokens by default" do
      {client, org, user} = setup_dependencies()

      token1 = build_agent_token(client.id, org.id, user.id)
      token2 = build_agent_token(client.id, org.id, user.id)

      {:ok, saved1} = PostgresqlAgentTokenRepository.save(token1)
      {:ok, _saved2} = PostgresqlAgentTokenRepository.save(token2)

      # Revoke first token
      PostgresqlAgentTokenRepository.revoke(saved1.id, "Test")

      # Should only return active token
      assert {:ok, tokens} = PostgresqlAgentTokenRepository.find_by_organization(org.id)
      assert length(tokens) == 1
      assert Enum.all?(tokens, &(&1.status == :active))
    end

    test "includes revoked tokens when requested" do
      {client, org, user} = setup_dependencies()

      token1 = build_agent_token(client.id, org.id, user.id)
      token2 = build_agent_token(client.id, org.id, user.id)

      {:ok, saved1} = PostgresqlAgentTokenRepository.save(token1)
      {:ok, _saved2} = PostgresqlAgentTokenRepository.save(token2)

      # Revoke first token
      PostgresqlAgentTokenRepository.revoke(saved1.id, "Test")

      # Should return both
      assert {:ok, tokens} =
               PostgresqlAgentTokenRepository.find_by_organization(org.id, include_revoked: true)

      assert length(tokens) == 2
    end

    test "enforces multi-tenant isolation" do
      {client1, org1, user1} = setup_dependencies()
      {client2, org2, user2} = setup_dependencies()

      # Create tokens for org1
      token1 = build_agent_token(client1.id, org1.id, user1.id)
      PostgresqlAgentTokenRepository.save(token1)

      # Create tokens for org2
      token2 = build_agent_token(client2.id, org2.id, user2.id)
      PostgresqlAgentTokenRepository.save(token2)

      # Query org1 - should only see org1 tokens
      {:ok, org1_tokens} = PostgresqlAgentTokenRepository.find_by_organization(org1.id)
      assert length(org1_tokens) == 1
      assert Enum.all?(org1_tokens, &(&1.organization_id == "org_" <> org1.id))

      # Query org2 - should only see org2 tokens
      {:ok, org2_tokens} = PostgresqlAgentTokenRepository.find_by_organization(org2.id)
      assert length(org2_tokens) == 1
      assert Enum.all?(org2_tokens, &(&1.organization_id == "org_" <> org2.id))
    end

    test "returns empty list for organization with no tokens" do
      {_client, org, _user} = setup_dependencies()

      assert {:ok, tokens} = PostgresqlAgentTokenRepository.find_by_organization(org.id)
      assert tokens == []
    end
  end

  describe "revoke/2" do
    test "revokes token successfully" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

      assert {:ok, revoked_token} =
               PostgresqlAgentTokenRepository.revoke(saved.id, "Manual revocation")

      assert %AgentToken{} = revoked_token
      assert revoked_token.status == :revoked
      assert revoked_token.revoke_reason == "Manual revocation"
      assert not is_nil(revoked_token.revoked_at)

      # Verify in database
      schema = Repo.get(AgentTokenSchema, saved.id)
      assert not is_nil(schema.revoked_at)
      assert schema.revoke_reason == "Manual revocation"
    end

    test "revokes without reason" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

      assert {:ok, revoked_token} = PostgresqlAgentTokenRepository.revoke(saved.id)

      assert revoked_token.status == :revoked
      assert is_nil(revoked_token.revoke_reason)
      assert not is_nil(revoked_token.revoked_at)
    end

    test "returns error when token not found" do
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} = PostgresqlAgentTokenRepository.revoke(fake_id)
    end

    test "can revoke already revoked token" do
      {client, org, user} = setup_dependencies()
      token = build_agent_token(client.id, org.id, user.id)
      {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

      # Revoke first time
      {:ok, _} = PostgresqlAgentTokenRepository.revoke(saved.id, "First")

      # Revoke again
      assert {:ok, revoked} = PostgresqlAgentTokenRepository.revoke(saved.id, "Second")
      assert revoked.status == :revoked
      # Note: reason will be updated to "Second"
    end
  end

  describe "revoke_delegation_chain/2" do
    test "revokes parent and all descendants" do
      {client, org, user} = setup_dependencies()

      # Create delegation chain: parent -> child1 -> grandchild
      parent = build_agent_token(client.id, org.id, user.id)
      {:ok, saved_parent} = PostgresqlAgentTokenRepository.save(parent)

      {:ok, chain1} =
        DelegationChain.new(%{parent_token_id: parent.id, depth: 1, path: [parent.id]})

      child1 = build_agent_token(client.id, org.id, user.id, %{delegation_chain: chain1})
      {:ok, saved_child1} = PostgresqlAgentTokenRepository.save(child1)

      {:ok, chain2} =
        DelegationChain.new(%{
          parent_token_id: child1.id,
          depth: 2,
          path: [parent.id, child1.id]
        })

      grandchild = build_agent_token(client.id, org.id, user.id, %{delegation_chain: chain2})
      {:ok, saved_grandchild} = PostgresqlAgentTokenRepository.save(grandchild)

      # Revoke entire chain
      assert {:ok, count} =
               PostgresqlAgentTokenRepository.revoke_delegation_chain(parent.id, "Chain revoked")

      # Should revoke 3 tokens (parent + child1 + grandchild)
      assert count == 3

      # Verify all are revoked
      {:ok, parent_revoked} = PostgresqlAgentTokenRepository.find_by_id(saved_parent.id)
      {:ok, child1_revoked} = PostgresqlAgentTokenRepository.find_by_id(saved_child1.id)
      {:ok, grandchild_revoked} = PostgresqlAgentTokenRepository.find_by_id(saved_grandchild.id)

      assert parent_revoked.status == :revoked
      assert child1_revoked.status == :revoked
      assert grandchild_revoked.status == :revoked
    end

    test "revokes only descendants, not siblings" do
      {client, org, user} = setup_dependencies()

      # Create parent with two children (siblings)
      parent = build_agent_token(client.id, org.id, user.id)
      {:ok, _saved_parent} = PostgresqlAgentTokenRepository.save(parent)

      {:ok, chain1} =
        DelegationChain.new(%{parent_token_id: parent.id, depth: 1, path: [parent.id]})

      child1 = build_agent_token(client.id, org.id, user.id, %{delegation_chain: chain1})
      {:ok, saved_child1} = PostgresqlAgentTokenRepository.save(child1)

      {:ok, chain2} =
        DelegationChain.new(%{parent_token_id: parent.id, depth: 1, path: [parent.id]})

      child2 = build_agent_token(client.id, org.id, user.id, %{delegation_chain: chain2})
      {:ok, saved_child2} = PostgresqlAgentTokenRepository.save(child2)

      # Revoke child1's chain (should not affect child2)
      assert {:ok, count} = PostgresqlAgentTokenRepository.revoke_delegation_chain(child1.id)

      # Should only revoke child1
      assert count == 1

      # Verify child1 revoked but child2 still active
      {:ok, child1_revoked} = PostgresqlAgentTokenRepository.find_by_id(saved_child1.id)
      {:ok, child2_active} = PostgresqlAgentTokenRepository.find_by_id(saved_child2.id)

      assert child1_revoked.status == :revoked
      assert child2_active.status == :active
    end

    test "handles deep delegation chains" do
      {client, org, user} = setup_dependencies()

      # Create chain of depth 4 (max allowed)
      tokens =
        Enum.reduce(0..3, [], fn depth, acc ->
          parent_id = if depth == 0, do: nil, else: List.first(acc).id

          {:ok, chain} =
            if depth == 0 do
              DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
            else
              path = Enum.map(Enum.reverse(acc), & &1.id)

              DelegationChain.new(%{
                parent_token_id: parent_id,
                depth: depth,
                path: path
              })
            end

          token = build_agent_token(client.id, org.id, user.id, %{delegation_chain: chain})
          {:ok, saved} = PostgresqlAgentTokenRepository.save(token)

          [saved | acc]
        end)

      # Revoke from root
      root_token = List.last(tokens)

      assert {:ok, count} = PostgresqlAgentTokenRepository.revoke_delegation_chain(root_token.id)

      # Should revoke all 4 tokens
      assert count == 4

      # Verify all revoked
      for token <- tokens do
        {:ok, revoked} = PostgresqlAgentTokenRepository.find_by_id(token.id)
        assert revoked.status == :revoked
      end
    end

    test "returns error when parent not found" do
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               PostgresqlAgentTokenRepository.revoke_delegation_chain(fake_id)
    end
  end

  describe "count_active_by_organization/1" do
    test "counts only active tokens" do
      {client, org, user} = setup_dependencies()

      # Create 3 tokens
      token1 = build_agent_token(client.id, org.id, user.id)
      token2 = build_agent_token(client.id, org.id, user.id)
      token3 = build_agent_token(client.id, org.id, user.id)

      {:ok, saved1} = PostgresqlAgentTokenRepository.save(token1)
      {:ok, _saved2} = PostgresqlAgentTokenRepository.save(token2)
      {:ok, _saved3} = PostgresqlAgentTokenRepository.save(token3)

      # Revoke one
      PostgresqlAgentTokenRepository.revoke(saved1.id)

      # Should count 2 active
      assert {:ok, count} = PostgresqlAgentTokenRepository.count_active_by_organization(org.id)
      assert count == 2
    end

    test "excludes expired tokens" do
      {client, org, user} = setup_dependencies()

      # Create expired token (expires_in = 1 second)
      expired_token = build_agent_token(client.id, org.id, user.id, %{expires_in: 1})
      {:ok, _saved_expired} = PostgresqlAgentTokenRepository.save(expired_token)

      # Wait for expiration
      :timer.sleep(1100)

      # Create active token
      active_token = build_agent_token(client.id, org.id, user.id, %{expires_in: 3600})
      {:ok, _saved_active} = PostgresqlAgentTokenRepository.save(active_token)

      # Should only count active (non-expired) tokens
      assert {:ok, count} = PostgresqlAgentTokenRepository.count_active_by_organization(org.id)
      assert count == 1
    end

    test "returns 0 for organization with no tokens" do
      {_client, org, _user} = setup_dependencies()

      assert {:ok, count} = PostgresqlAgentTokenRepository.count_active_by_organization(org.id)
      assert count == 0
    end

    test "enforces multi-tenant isolation in counting" do
      {client1, org1, user1} = setup_dependencies()
      {client2, org2, user2} = setup_dependencies()

      # Create 2 tokens for org1
      token1 = build_agent_token(client1.id, org1.id, user1.id)
      token2 = build_agent_token(client1.id, org1.id, user1.id)
      PostgresqlAgentTokenRepository.save(token1)
      PostgresqlAgentTokenRepository.save(token2)

      # Create 1 token for org2
      token3 = build_agent_token(client2.id, org2.id, user2.id)
      PostgresqlAgentTokenRepository.save(token3)

      # Count for org1
      {:ok, count1} = PostgresqlAgentTokenRepository.count_active_by_organization(org1.id)
      assert count1 == 2

      # Count for org2
      {:ok, count2} = PostgresqlAgentTokenRepository.count_active_by_organization(org2.id)
      assert count2 == 1
    end
  end

  # Helper functions

  defp setup_dependencies do
    # Create organization using the proper changeset
    org =
      OrganizationSchema.create_changeset(%{
        name: "Test Org #{System.unique_integer([:positive])}"
      })
      |> Repo.insert!()

    # Create user using the proper changeset
    user =
      UserSchema.create_changeset(%{
        email: "test#{System.unique_integer([:positive])}@example.com",
        password_hash: Bcrypt.hash_pwd_salt("password123"),
        organization_id: org.id,
        status: :active
      })
      |> Repo.insert!()

    # Create OAuth2 client using the proper changeset
    client =
      OAuth2ClientSchema.create_changeset(%{
        name: "Test Client #{System.unique_integer([:positive])}",
        client_id_string: "client_#{System.unique_integer([:positive])}",
        client_type: :confidential,
        client_secret: Bcrypt.hash_pwd_salt("secret"),
        redirect_uris: ["http://localhost:3000/callback"],
        allowed_scopes: ["read:data", "write:results"],
        allowed_grant_types: ["authorization_code", "refresh_token"],
        organization_id: org.id
      })
      |> Repo.insert!()

    {client, org, user}
  end

  defp build_agent_token(client_id, org_id, user_id, overrides \\ %{}) do
    {:ok, agent_type} = AgentType.new(:autonomous)
    {:ok, task_id} = TaskId.new(Ecto.UUID.generate())

    {:ok, delegation_chain} =
      DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})

    base_params = %{
      client_id: client_id,
      organization_id: org_id,
      agent_type: agent_type,
      task_id: task_id,
      task_description: "Test task #{System.unique_integer([:positive])}",
      scopes: ["read:data", "write:results"],
      delegation_chain: delegation_chain,
      delegator_user_id: user_id,
      expires_in: 3600,
      reason: "Test token"
    }

    params = Map.merge(base_params, overrides)

    {:ok, token} = AgentToken.create(params)
    token
  end
end
