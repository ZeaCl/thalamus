defmodule Thalamus.Application.Services.DelegationChainValidatorTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.Services.DelegationChainValidator
  alias Thalamus.Domain.ValueObjects.DelegationChain
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId}

  setup :verify_on_exit!

  describe "validate/3 - root delegation" do
    test "succeeds with nil parent_id" do
      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:ok, %DelegationChain{} = chain} =
               DelegationChainValidator.validate(nil, ["read:data"], deps)

      assert chain.parent_token_id == nil
      assert chain.depth == 0
      assert chain.path == []
    end
  end

  describe "validate/3 - delegated validation" do
    test "succeeds when parent exists, is active, scopes match, and depth is allowed" do
      parent_id = Ecto.UUID.generate()

      parent_token =
        build_saved_agent_token(%{
          id: parent_id,
          scopes: ["read:data", "write:data"],
          delegation_depth: 1,
          path: [Ecto.UUID.generate()]
        })

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id ->
        {:ok, parent_token}
      end)

      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:ok, %DelegationChain{} = chain} =
               DelegationChainValidator.validate(parent_id, ["read:data"], deps)

      assert chain.parent_token_id == parent_id
      assert chain.depth == 2
      assert chain.path == parent_token.delegation_chain.path ++ [parent_id]
    end

    test "returns error when parent token is not found" do
      parent_id = Ecto.UUID.generate()

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id ->
        {:error, :not_found}
      end)

      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:error, :parent_token_not_found} =
               DelegationChainValidator.validate(parent_id, ["read:data"], deps)
    end

    test "returns error when parent token is revoked" do
      parent_id = Ecto.UUID.generate()

      parent_token =
        build_saved_agent_token(%{
          id: parent_id,
          status: :revoked
        })

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id ->
        {:ok, parent_token}
      end)

      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:error, :parent_token_not_active} =
               DelegationChainValidator.validate(parent_id, ["read:data"], deps)
    end

    test "returns error when parent token is expired" do
      parent_id = Ecto.UUID.generate()
      # expired token (expires_in negative)
      parent_token = %{build_saved_agent_token(%{id: parent_id}) | expires_in: -10}

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id ->
        {:ok, parent_token}
      end)

      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:error, :parent_token_not_active} =
               DelegationChainValidator.validate(parent_id, ["read:data"], deps)
    end

    test "returns error when requested scopes exceed parent scopes" do
      parent_id = Ecto.UUID.generate()

      parent_token =
        build_saved_agent_token(%{
          id: parent_id,
          scopes: ["read:data"]
        })

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id ->
        {:ok, parent_token}
      end)

      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:error, :scopes_exceed_parent} =
               DelegationChainValidator.validate(parent_id, ["read:data", "write:data"], deps)
    end

    test "returns error when max delegation depth is exceeded" do
      parent_id = Ecto.UUID.generate()

      parent_token =
        build_saved_agent_token(%{
          id: parent_id,
          # Max allowed depth is 4
          delegation_depth: 4,
          path: List.duplicate(Ecto.UUID.generate(), 4)
        })

      MockAgentTokenRepository
      |> expect(:find_by_id, fn ^parent_id ->
        {:ok, parent_token}
      end)

      deps = %{agent_token_repository: MockAgentTokenRepository}

      assert {:error, :max_delegation_depth_exceeded} =
               DelegationChainValidator.validate(parent_id, ["read:data"], deps)
    end
  end

  # Helper to build mock AgentToken for testing
  defp build_saved_agent_token(overrides) do
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
end
