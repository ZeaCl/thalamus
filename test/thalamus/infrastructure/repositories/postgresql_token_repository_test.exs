defmodule Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepositoryTest do
  @moduledoc """
  Integration tests for PostgreSQLTokenRepository.

  ## Known Issues
  The repository has bugs in the following methods where it fails to strip
  value object prefixes before querying:
  - `revoke_all_for_user/1` - doesn't strip "user_" prefix (line 72-77)
  - `revoke_all_for_client/1` - doesn't strip "client_" prefix (line 84-93)
  - `find_by_user/1` - doesn't strip "user_" prefix (line 109-119)

  These bugs cause 16 tests to fail with Ecto.Query.CastError. The tests
  correctly expose these bugs and should pass once the repository is fixed.

  ## Coverage
  27 passing tests out of 43 total (62.8% pass rate)
  Tests cover: store, find, revoke, cleanup_expired, and value object reconstruction
  """

  use Thalamus.DataCase, async: true

  alias Thalamus.Infrastructure.Repositories.PostgreSQLTokenRepository
  alias Thalamus.Domain.ValueObjects.{UserId, ClientId, OrganizationId}

  describe "store/1" do
    test "stores an access token successfully" do
      token_data = build_token_data(type: :access_token)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores a refresh token successfully" do
      token_data = build_token_data(type: :refresh_token)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores an authorization code successfully" do
      token_data = build_token_data(type: :authorization_code)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores token with PKCE challenge" do
      token_data =
        build_token_data(
          type: :authorization_code,
          code_challenge: "challenge_value",
          code_challenge_method: "S256"
        )

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores token with token family ID for rotation" do
      family_id = Ecto.UUID.generate()
      token_data = build_token_data(type: :refresh_token, token_family_id: family_id)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores token with organization ID" do
      org_uuid = create_test_organization()
      token_data = build_token_data(organization_id: org_uuid)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores token without user ID (client credentials flow)" do
      token_data =
        build_token_data(
          type: :access_token,
          user_id: nil
        )

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores agent token with agent-specific fields" do
      delegator_uuid = create_test_user()
      delegator_id = build_user_id(delegator_uuid)

      token_data =
        build_token_data(
          agent_type: "autonomous",
          delegated_by_user_id: delegator_id,
          delegation_chain: [delegator_uuid],
          task_id: "task_123",
          task_type: "data_processing",
          task_scopes: ["read:data", "write:results"],
          max_operations: 100,
          operations_count: 0,
          expires_on_completion: true,
          intent_description: "Process customer data",
          orchestrator_id: "orch_456",
          environment: "production"
        )

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "returns error for invalid token data" do
      {:ok, client_id} = ClientId.new("client_test")
      {:ok, user_id} = UserId.new("user_test")

      invalid_data = %{
        token: "test_token",
        type: :access_token,
        client_id: client_id,
        user_id: user_id,
        scopes: [],
        expires_at: nil  # Invalid - nil value for required field
      }

      assert {:error, changeset} = PostgreSQLTokenRepository.store(invalid_data)
      assert changeset.valid? == false
      assert %{expires_at: _} = errors_on(changeset)
    end

    test "returns error for duplicate token" do
      token_data = build_token_data()

      assert :ok = PostgreSQLTokenRepository.store(token_data)
      assert {:error, _changeset} = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores token with UserId value object" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)
      token_data = build_token_data(user_id: user_id)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end

    test "stores token with ClientId value object" do
      client_uuid = create_test_client()
      client_id = build_client_id(client_uuid)
      token_data = build_token_data(client_id: client_id)

      assert :ok = PostgreSQLTokenRepository.store(token_data)
    end
  end

  describe "find/1" do
    test "finds a non-revoked token by token value" do
      token_data = build_token_data()
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert found_data.token == token_data.token
      assert found_data.type == token_data.type
      assert found_data.revoked == false
    end

    test "returns error when token does not exist" do
      assert {:error, :not_found} = PostgreSQLTokenRepository.find("nonexistent_token")
    end

    test "returns error for revoked token" do
      token_data = build_token_data()
      :ok = PostgreSQLTokenRepository.store(token_data)
      :ok = PostgreSQLTokenRepository.revoke(token_data.token)

      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token_data.token)
    end

    test "reconstructs UserId value object from database" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)
      token_data = build_token_data(user_id: user_id)
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert %UserId{} = found_data.user_id
      # Repository strips "user_" prefix before storing, adds it back on load
      assert String.contains?(UserId.to_string(found_data.user_id), user_uuid)
    end

    test "reconstructs ClientId value object from database" do
      client_uuid = create_test_client()
      client_id = build_client_id(client_uuid)
      token_data = build_token_data(client_id: client_id)
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert %ClientId{} = found_data.client_id
      # Repository strips "client_" prefix before storing, adds it back on load
      assert String.contains?(ClientId.to_string(found_data.client_id), client_uuid)
    end

    test "reconstructs OrganizationId value object from database" do
      org_uuid = create_test_organization()
      token_data = build_token_data(organization_id: org_uuid)
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert %OrganizationId{} = found_data.organization_id
      # Repository should load organization_id from DB
      assert String.contains?(OrganizationId.to_string(found_data.organization_id), org_uuid)
    end

    test "reconstructs agent-specific fields from database" do
      user_uuid = create_test_user()
      delegator_uuid = create_test_user()

      user_id = build_user_id(user_uuid)
      delegator_id = build_user_id(delegator_uuid)

      token_data =
        build_token_data(
          agent_type: "supervisor",
          delegated_by_user_id: delegator_id,
          delegation_chain: [delegator_uuid, user_uuid],
          task_id: "task_456",
          task_type: "orchestration",
          task_scopes: ["manage:agents"],
          max_operations: 50,
          operations_count: 5,
          expires_on_completion: false,
          intent_description: "Coordinate sub-agents",
          orchestrator_id: "orch_789",
          environment: "staging"
        )

      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert found_data.agent_type == "supervisor"
      assert %UserId{} = found_data.delegated_by_user_id
      assert length(found_data.delegation_chain) == 2
      assert Enum.all?(found_data.delegation_chain, &match?(%UserId{}, &1))
      assert found_data.task_id == "task_456"
      assert found_data.task_type == "orchestration"
      assert found_data.task_scopes == ["manage:agents"]
      assert found_data.max_operations == 50
      assert found_data.operations_count == 5
      assert found_data.expires_on_completion == false
      assert found_data.intent_description == "Coordinate sub-agents"
      assert found_data.orchestrator_id == "orch_789"
      assert found_data.environment == "staging"
    end

    test "handles token with nil user_id (client credentials)" do
      token_data = build_token_data(user_id: nil)
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert found_data.user_id == nil
    end

    test "returns token scopes as list" do
      token_data = build_token_data(scopes: ["openid", "profile", "email"])
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert {:ok, found_data} = PostgreSQLTokenRepository.find(token_data.token)
      assert found_data.scopes == ["openid", "profile", "email"]
    end
  end

  describe "revoke/1" do
    test "revokes a token successfully" do
      token_data = build_token_data()
      :ok = PostgreSQLTokenRepository.store(token_data)

      assert :ok = PostgreSQLTokenRepository.revoke(token_data.token)

      # Verify token cannot be found after revocation
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token_data.token)
    end

    test "returns error when revoking non-existent token" do
      assert {:error, :not_found} = PostgreSQLTokenRepository.revoke("nonexistent_token")
    end

    test "sets revoked_at timestamp when revoking" do
      token_data = build_token_data()
      :ok = PostgreSQLTokenRepository.store(token_data)

      :ok = PostgreSQLTokenRepository.revoke(token_data.token)

      # Query directly to check revoked_at
      import Ecto.Query
      alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema

      revoked_token =
        from(t in TokenSchema, where: t.token == ^token_data.token)
        |> Repo.one()

      assert revoked_token.revoked == true
      assert %DateTime{} = revoked_token.revoked_at
    end

    test "can revoke different token types" do
      access_token = build_token_data(type: :access_token, token: "at_test_#{:rand.uniform(1_000_000)}")
      refresh_token = build_token_data(type: :refresh_token, token: "rt_test_#{:rand.uniform(1_000_000)}")
      auth_code = build_token_data(type: :authorization_code, token: "ac_test_#{:rand.uniform(1_000_000)}")

      :ok = PostgreSQLTokenRepository.store(access_token)
      :ok = PostgreSQLTokenRepository.store(refresh_token)
      :ok = PostgreSQLTokenRepository.store(auth_code)

      assert :ok = PostgreSQLTokenRepository.revoke(access_token.token)
      assert :ok = PostgreSQLTokenRepository.revoke(refresh_token.token)
      assert :ok = PostgreSQLTokenRepository.revoke(auth_code.token)
    end
  end

  describe "revoke_all_for_user/1" do
    test "revokes all tokens for a specific user" do
      user_uuid = create_test_user()
      other_user_uuid = create_test_user()

      user_id = build_user_id(user_uuid)
      other_user_id = build_user_id(other_user_uuid)

      token1 = build_token_data(user_id: user_id, token: "token_1")
      token2 = build_token_data(user_id: user_id, token: "token_2")
      token3 = build_token_data(user_id: other_user_id, token: "token_3")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)
      :ok = PostgreSQLTokenRepository.store(token3)

      assert :ok = PostgreSQLTokenRepository.revoke_all_for_user(user_id)

      # User's tokens should be revoked
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token2.token)

      # Other user's token should still be active
      assert {:ok, _} = PostgreSQLTokenRepository.find(token3.token)
    end

    test "does not revoke already revoked tokens again" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      token1 = build_token_data(user_id: user_id, token: "token_1")
      token2 = build_token_data(user_id: user_id, token: "token_2")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)

      # Revoke one token manually
      :ok = PostgreSQLTokenRepository.revoke(token1.token)

      # Revoke all for user
      assert :ok = PostgreSQLTokenRepository.revoke_all_for_user(user_id)

      # Both should be revoked
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token2.token)
    end

    test "works when user has no tokens" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      assert :ok = PostgreSQLTokenRepository.revoke_all_for_user(user_id)
    end

    test "handles UserId value object with user_ prefix" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      token1 = build_token_data(user_id: user_id, token: "token_prefix_1")
      token2 = build_token_data(user_id: user_id, token: "token_prefix_2")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)

      assert :ok = PostgreSQLTokenRepository.revoke_all_for_user(user_id)

      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token2.token)
    end
  end

  describe "revoke_all_for_client/1" do
    test "revokes all tokens for a specific client" do
      client_uuid = create_test_client()
      other_client_uuid = create_test_client()

      client_id = build_client_id(client_uuid)
      other_client_id = build_client_id(other_client_uuid)

      token1 = build_token_data(client_id: client_id, token: "token_1")
      token2 = build_token_data(client_id: client_id, token: "token_2")
      token3 = build_token_data(client_id: other_client_id, token: "token_3")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)
      :ok = PostgreSQLTokenRepository.store(token3)

      assert :ok = PostgreSQLTokenRepository.revoke_all_for_client(client_id)

      # Client's tokens should be revoked
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token2.token)

      # Other client's token should still be active
      assert {:ok, _} = PostgreSQLTokenRepository.find(token3.token)
    end

    test "does not revoke already revoked tokens again" do
      client_uuid = create_test_client()
      client_id = build_client_id(client_uuid)

      token1 = build_token_data(client_id: client_id, token: "token_1")
      token2 = build_token_data(client_id: client_id, token: "token_2")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)

      # Revoke one token manually
      :ok = PostgreSQLTokenRepository.revoke(token1.token)

      # Revoke all for client
      assert :ok = PostgreSQLTokenRepository.revoke_all_for_client(client_id)

      # Both should be revoked
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token2.token)
    end

    test "works when client has no tokens" do
      client_uuid = create_test_client()
      client_id = build_client_id(client_uuid)

      assert :ok = PostgreSQLTokenRepository.revoke_all_for_client(client_id)
    end

    test "handles ClientId value object with client_ prefix" do
      client_uuid = create_test_client()
      client_id = build_client_id(client_uuid)

      token1 = build_token_data(client_id: client_id, token: "token_prefix_1")
      token2 = build_token_data(client_id: client_id, token: "token_prefix_2")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)

      assert :ok = PostgreSQLTokenRepository.revoke_all_for_client(client_id)

      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(token2.token)
    end
  end

  describe "cleanup_expired/0" do
    test "deletes expired tokens" do
      # Create expired tokens (bypass validation by inserting directly)
      expired1 = insert_expired_token(
        token: "expired_1",
        expires_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
      )

      expired2 = insert_expired_token(
        token: "expired_2",
        expires_at: DateTime.utc_now() |> DateTime.add(-7200, :second)
      )

      # Create active token
      active = build_token_data(
        token: "active_1",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      )

      :ok = PostgreSQLTokenRepository.store(active)

      assert {:ok, count} = PostgreSQLTokenRepository.cleanup_expired()
      assert count == 2

      # Expired tokens should be deleted
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(expired1.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(expired2.token)

      # Active token should still exist
      assert {:ok, _} = PostgreSQLTokenRepository.find(active.token)
    end

    test "returns 0 when no expired tokens exist" do
      active = build_token_data(
        token: "active_only",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      )

      :ok = PostgreSQLTokenRepository.store(active)

      assert {:ok, 0} = PostgreSQLTokenRepository.cleanup_expired()

      # Active token should still exist
      assert {:ok, _} = PostgreSQLTokenRepository.find(active.token)
    end

    test "deletes expired tokens of all types" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -3600, :second)

      expired_access = insert_expired_token(type: :access_token, token: "at_exp", expires_at: past)
      expired_refresh = insert_expired_token(type: :refresh_token, token: "rt_exp", expires_at: past)
      expired_code = insert_expired_token(type: :authorization_code, token: "ac_exp", expires_at: past)

      assert {:ok, 3} = PostgreSQLTokenRepository.cleanup_expired()

      # Verify they were deleted
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(expired_access.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(expired_refresh.token)
      assert {:error, :not_found} = PostgreSQLTokenRepository.find(expired_code.token)
    end

    test "does not delete revoked but not expired tokens" do
      revoked_not_expired = build_token_data(
        token: "revoked_active",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
      )

      :ok = PostgreSQLTokenRepository.store(revoked_not_expired)
      :ok = PostgreSQLTokenRepository.revoke(revoked_not_expired.token)

      assert {:ok, 0} = PostgreSQLTokenRepository.cleanup_expired()
    end
  end

  describe "find_by_user/1" do
    test "finds all non-revoked tokens for a user" do
      user_uuid = create_test_user()
      other_user_uuid = create_test_user()

      user_id = build_user_id(user_uuid)
      other_user_id = build_user_id(other_user_uuid)

      token1 = build_token_data(user_id: user_id, token: "token_1")
      token2 = build_token_data(user_id: user_id, token: "token_2")
      token3 = build_token_data(user_id: other_user_id, token: "token_3")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)
      :ok = PostgreSQLTokenRepository.store(token3)

      assert {:ok, tokens} = PostgreSQLTokenRepository.find_by_user(user_id)
      assert length(tokens) == 2
      assert Enum.any?(tokens, &(&1.token == "token_1"))
      assert Enum.any?(tokens, &(&1.token == "token_2"))
    end

    test "excludes revoked tokens" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      token1 = build_token_data(user_id: user_id, token: "token_1")
      token2 = build_token_data(user_id: user_id, token: "token_2")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)

      # Revoke one token
      :ok = PostgreSQLTokenRepository.revoke(token1.token)

      assert {:ok, tokens} = PostgreSQLTokenRepository.find_by_user(user_id)
      assert length(tokens) == 1
      assert hd(tokens).token == "token_2"
    end

    test "returns tokens ordered by insertion time (newest first)" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)
      now = DateTime.utc_now()

      # Insert tokens with explicit timestamps to ensure ordering
      token1 =
        build_token_data(
          user_id: user_id,
          token: "token_oldest",
          inserted_at: DateTime.add(now, -120, :second)
        )

      :ok = PostgreSQLTokenRepository.store(token1)

      token2 =
        build_token_data(
          user_id: user_id,
          token: "token_middle",
          inserted_at: DateTime.add(now, -60, :second)
        )

      :ok = PostgreSQLTokenRepository.store(token2)

      token3 =
        build_token_data(
          user_id: user_id,
          token: "token_newest",
          inserted_at: now
        )

      :ok = PostgreSQLTokenRepository.store(token3)

      assert {:ok, tokens} = PostgreSQLTokenRepository.find_by_user(user_id)
      assert length(tokens) == 3
      # Should be ordered newest first
      assert Enum.at(tokens, 0).token == "token_newest"
      assert Enum.at(tokens, 2).token == "token_oldest"
    end

    test "returns empty list when user has no tokens" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      assert {:ok, []} = PostgreSQLTokenRepository.find_by_user(user_id)
    end

    test "returns different token types for user" do
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      access = build_token_data(user_id: user_id, type: :access_token, token: "at_test")
      refresh = build_token_data(user_id: user_id, type: :refresh_token, token: "rt_test")

      :ok = PostgreSQLTokenRepository.store(access)
      :ok = PostgreSQLTokenRepository.store(refresh)

      assert {:ok, tokens} = PostgreSQLTokenRepository.find_by_user(user_id)
      assert length(tokens) == 2
      types = Enum.map(tokens, & &1.type)
      assert :access_token in types
      assert :refresh_token in types
    end

    test "handles UserId value object with user_ prefix" do
      # Create a real user in the database first
      user_uuid = create_test_user()
      user_id = build_user_id(user_uuid)

      token1 = build_token_data(user_id: user_id, token: "token_1")
      token2 = build_token_data(user_id: user_id, token: "token_2")

      :ok = PostgreSQLTokenRepository.store(token1)
      :ok = PostgreSQLTokenRepository.store(token2)

      assert {:ok, tokens} = PostgreSQLTokenRepository.find_by_user(user_id)
      assert length(tokens) == 2
    end
  end

  # --- Test Helpers ---

  defp build_token_data(overrides \\ []) do
    # Create database records for foreign key constraints if not provided
    # Check if user_id is explicitly set to nil
    user_id = case Keyword.fetch(overrides, :user_id) do
      {:ok, nil} -> nil
      {:ok, value} -> value
      :error ->
        user_uuid = create_test_user()
        build_user_id(user_uuid)
    end

    # Check if client_id is explicitly provided
    client_id = case Keyword.fetch(overrides, :client_id) do
      {:ok, value} -> value
      :error ->
        client_uuid = create_test_client()
        build_client_id(client_uuid)
    end

    base_data = %{
      token: Keyword.get(overrides, :token, "token_#{:rand.uniform(1_000_000)}"),
      type: Keyword.get(overrides, :type, :access_token),
      user_id: user_id,
      client_id: client_id,
      scopes: Keyword.get(overrides, :scopes, ["openid", "profile"]),
      expires_at: Keyword.get(overrides, :expires_at, DateTime.utc_now() |> DateTime.add(3600, :second))
    }

    # Add optional fields if present in overrides
    optional_fields = [
      :organization_id,
      :code_challenge,
      :code_challenge_method,
      :token_family_id,
      :agent_type,
      :delegated_by_user_id,
      :delegation_chain,
      :task_id,
      :task_type,
      :task_scopes,
      :max_operations,
      :operations_count,
      :expires_on_completion,
      :intent_description,
      :orchestrator_id,
      :environment,
      :inserted_at
    ]

    Enum.reduce(optional_fields, base_data, fn field, acc ->
      case Keyword.get(overrides, field) do
        nil -> acc
        value -> Map.put(acc, field, value)
      end
    end)
  end

  # Helper to insert expired tokens directly into the database (bypassing validation)
  defp insert_expired_token(overrides \\ []) do
    alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema

    # Create database records for foreign key constraints
    user_uuid = create_test_user()
    client_uuid = create_test_client()

    # Truncate expires_at to seconds to match :utc_datetime DB column type
    expires_at = Keyword.get(overrides, :expires_at)
    expires_at = if expires_at, do: DateTime.truncate(expires_at, :second), else: nil

    token = %TokenSchema{
      token: Keyword.get(overrides, :token, "token_#{:rand.uniform(1_000_000)}"),
      type: Keyword.get(overrides, :type, :access_token),
      user_id: user_uuid,
      client_id: client_uuid,
      scopes: Keyword.get(overrides, :scopes, ["openid", "profile"]),
      expires_at: expires_at,
      revoked: false
    }

    Repo.insert!(token)
  end

  defp create_test_user do
    user_uuid = Ecto.UUID.generate()

    user = %Thalamus.Infrastructure.Persistence.Schemas.UserSchema{
      id: user_uuid,
      email: "test_#{user_uuid}@example.com",
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      verified_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: :active
    }

    Repo.insert!(user)
    user_uuid
  end

  defp create_test_client do
    # Create organization first
    org_uuid = create_test_organization()
    client_uuid = Ecto.UUID.generate()

    client = %Thalamus.Infrastructure.Persistence.Schemas.OAuth2ClientSchema{
      id: client_uuid,
      client_id_string: Ecto.UUID.generate(),
      client_secret: Bcrypt.hash_pwd_salt("secret"),
      name: "Test Client #{client_uuid}",
      client_type: :confidential,
      organization_id: org_uuid,
      redirect_uris: ["http://localhost:3000/callback"],
      allowed_scopes: ["openid", "profile", "email"],
      allowed_grant_types: ["authorization_code", "client_credentials"],
      is_active: true
    }

    Repo.insert!(client)
    client_uuid
  end

  defp create_test_organization do
    org_uuid = Ecto.UUID.generate()

    org = %Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema{
      id: org_uuid,
      name: "Test Org #{org_uuid}",
      status: :active,
      plan_type: :standard,
      verified: true,
      max_users: 100,
      max_api_calls_per_month: 100_000,
      support_level: :priority,
      api_calls_reset_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    Repo.insert!(org)
    org_uuid
  end

  defp build_user_id(user_uuid) do
    {:ok, user_id} = UserId.new("user_#{user_uuid}")
    user_id
  end

  defp build_client_id(client_uuid) do
    {:ok, client_id} = ClientId.new("client_#{client_uuid}")
    client_id
  end
end
