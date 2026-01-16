defmodule Thalamus.Domain.ValueObjects.DelegationChainTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.DelegationChain

  describe "new/1 with valid inputs" do
    test "creates delegation chain with single user ID" do
      user_id = Ecto.UUID.generate()
      assert {:ok, %DelegationChain{chain: [^user_id]}} = DelegationChain.new([user_id])
    end

    test "creates delegation chain with multiple user IDs" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()
      user_id3 = Ecto.UUID.generate()

      assert {:ok, %DelegationChain{chain: [^user_id1, ^user_id2, ^user_id3]}} =
               DelegationChain.new([user_id1, user_id2, user_id3])
    end

    test "creates delegation chain with maximum depth (10 levels)" do
      chain = for _i <- 1..10, do: Ecto.UUID.generate()
      assert {:ok, %DelegationChain{chain: ^chain}} = DelegationChain.new(chain)
    end

    test "preserves order of delegation" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()
      user_id3 = Ecto.UUID.generate()

      {:ok, delegation_chain} = DelegationChain.new([user_id1, user_id2, user_id3])

      assert delegation_chain.chain == [user_id1, user_id2, user_id3]
    end

    test "allows duplicate user IDs (re-delegation)" do
      user_id = Ecto.UUID.generate()

      assert {:ok, %DelegationChain{chain: [^user_id, ^user_id]}} =
               DelegationChain.new([user_id, user_id])
    end
  end

  describe "new/1 with invalid inputs" do
    test "fails with empty list" do
      assert {:error, :empty_delegation_chain} = DelegationChain.new([])
    end

    test "fails with nil" do
      assert {:error, :invalid_delegation_chain} = DelegationChain.new(nil)
    end

    test "fails with non-list input" do
      assert {:error, :invalid_delegation_chain} = DelegationChain.new("user_123")
      assert {:error, :invalid_delegation_chain} = DelegationChain.new(123)
      assert {:error, :invalid_delegation_chain} = DelegationChain.new(%{})
    end

    test "fails with chain exceeding max depth (> 10 levels)" do
      chain = for _i <- 1..11, do: Ecto.UUID.generate()
      assert {:error, :delegation_chain_too_deep} = DelegationChain.new(chain)
    end

    test "fails with very deep chain (100 levels)" do
      chain = for _i <- 1..100, do: Ecto.UUID.generate()
      assert {:error, :delegation_chain_too_deep} = DelegationChain.new(chain)
    end

    test "accepts non-UUID strings in chain for flexibility" do
      user_id1 = Ecto.UUID.generate()
      # Non-UUID but valid string
      custom_id = "user_12345"
      user_id2 = Ecto.UUID.generate()

      assert {:ok, %DelegationChain{chain: [^user_id1, ^custom_id, ^user_id2]}} =
               DelegationChain.new([user_id1, custom_id, user_id2])
    end

    test "fails with non-binary user ID" do
      user_id1 = Ecto.UUID.generate()

      assert {:error, :invalid_user_id_in_chain} =
               DelegationChain.new([user_id1, 123, Ecto.UUID.generate()])
    end
  end

  describe "from_delegator/1" do
    test "creates delegation chain from single delegator ID" do
      user_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.from_delegator(user_id)

      assert chain.chain == [user_id]
    end

    test "creates valid delegation chain ready for extension" do
      user_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.from_delegator(user_id)

      assert DelegationChain.depth(chain) == 1
    end
  end

  describe "append/2" do
    test "appends new user to delegation chain" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.from_delegator(user_id1)
      {:ok, new_chain} = DelegationChain.append(chain, user_id2)

      assert new_chain.chain == [user_id1, user_id2]
    end

    test "appends multiple users sequentially" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()
      user_id3 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.from_delegator(user_id1)
      {:ok, chain} = DelegationChain.append(chain, user_id2)
      {:ok, chain} = DelegationChain.append(chain, user_id3)

      assert chain.chain == [user_id1, user_id2, user_id3]
    end

    test "fails when appending would exceed max depth" do
      # Create chain at max depth
      chain_ids = for _i <- 1..10, do: Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new(chain_ids)

      # Try to append one more
      new_user_id = Ecto.UUID.generate()
      assert {:error, :delegation_chain_too_deep} = DelegationChain.append(chain, new_user_id)
    end

    test "allows re-delegation to same user" do
      user_id = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.from_delegator(user_id)
      {:ok, new_chain} = DelegationChain.append(chain, user_id)

      assert new_chain.chain == [user_id, user_id]
    end

    test "accepts custom string user IDs" do
      {:ok, chain} = DelegationChain.from_delegator(Ecto.UUID.generate())

      assert {:ok, new_chain} =
               DelegationChain.append(chain, "custom-user-id-123")

      assert DelegationChain.depth(new_chain) == 2
    end
  end

  describe "depth/1" do
    test "returns 1 for single-user chain" do
      {:ok, chain} = DelegationChain.from_delegator(Ecto.UUID.generate())
      assert DelegationChain.depth(chain) == 1
    end

    test "returns correct depth for multi-user chain" do
      chain_ids = for _i <- 1..5, do: Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new(chain_ids)

      assert DelegationChain.depth(chain) == 5
    end

    test "returns maximum depth for 10-level chain" do
      chain_ids = for _i <- 1..10, do: Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new(chain_ids)

      assert DelegationChain.depth(chain) == 10
    end
  end

  describe "to_list/1" do
    test "converts delegation chain to list of user IDs" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id1, user_id2])

      assert DelegationChain.to_list(chain) == [user_id1, user_id2]
    end

    test "preserves order in conversion" do
      chain_ids = for _i <- 1..5, do: Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new(chain_ids)

      assert DelegationChain.to_list(chain) == chain_ids
    end
  end

  describe "String.Chars protocol" do
    test "implements String.Chars protocol" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id1, user_id2])
      string_repr = to_string(chain)

      assert string_repr =~ user_id1
      assert string_repr =~ user_id2
      assert string_repr =~ " -> "
    end

    test "formats single-user chain" do
      user_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.from_delegator(user_id)

      assert to_string(chain) == user_id
    end

    test "formats multi-user chain with arrows" do
      user_id1 = "00000000-0000-0000-0000-000000000001"
      user_id2 = "00000000-0000-0000-0000-000000000002"
      user_id3 = "00000000-0000-0000-0000-000000000003"

      {:ok, chain} = DelegationChain.new([user_id1, user_id2, user_id3])

      assert to_string(chain) == "#{user_id1} -> #{user_id2} -> #{user_id3}"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes to JSON array" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id1, user_id2])
      json = Jason.encode!(chain)

      assert json == Jason.encode!([user_id1, user_id2])
    end

    test "encodes and decodes roundtrip" do
      chain_ids = for _i <- 1..3, do: Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new(chain_ids)

      json = Jason.encode!(chain)
      decoded_list = Jason.decode!(json)

      assert {:ok, roundtrip_chain} = DelegationChain.new(decoded_list)
      assert roundtrip_chain == chain
    end
  end

  describe "equality and comparison" do
    test "delegation chains with same IDs are equal" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()

      {:ok, chain1} = DelegationChain.new([user_id1, user_id2])
      {:ok, chain2} = DelegationChain.new([user_id1, user_id2])

      assert chain1 == chain2
    end

    test "delegation chains with different IDs are not equal" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()
      user_id3 = Ecto.UUID.generate()

      {:ok, chain1} = DelegationChain.new([user_id1, user_id2])
      {:ok, chain2} = DelegationChain.new([user_id1, user_id3])

      assert chain1 != chain2
    end

    test "order matters for equality" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()

      {:ok, chain1} = DelegationChain.new([user_id1, user_id2])
      {:ok, chain2} = DelegationChain.new([user_id2, user_id1])

      assert chain1 != chain2
    end
  end

  describe "delegation scenarios" do
    test "human delegates to autonomous agent" do
      human_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.from_delegator(human_id)

      assert DelegationChain.depth(chain) == 1
      assert List.first(chain.chain) == human_id
    end

    test "human delegates to supervised agent which delegates to sub-agent" do
      human_id = Ecto.UUID.generate()
      supervisor_agent_id = Ecto.UUID.generate()
      sub_agent_id = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.from_delegator(human_id)
      {:ok, chain} = DelegationChain.append(chain, supervisor_agent_id)
      {:ok, chain} = DelegationChain.append(chain, sub_agent_id)

      assert DelegationChain.depth(chain) == 3
      assert chain.chain == [human_id, supervisor_agent_id, sub_agent_id]
    end

    test "complex orchestration chain" do
      # Human -> Orchestrator -> Worker1 -> Worker2 -> Worker3
      human_id = Ecto.UUID.generate()
      orchestrator_id = Ecto.UUID.generate()
      worker1_id = Ecto.UUID.generate()
      worker2_id = Ecto.UUID.generate()
      worker3_id = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.from_delegator(human_id)
      {:ok, chain} = DelegationChain.append(chain, orchestrator_id)
      {:ok, chain} = DelegationChain.append(chain, worker1_id)
      {:ok, chain} = DelegationChain.append(chain, worker2_id)
      {:ok, chain} = DelegationChain.append(chain, worker3_id)

      assert DelegationChain.depth(chain) == 5
      assert List.first(chain.chain) == human_id
      assert List.last(chain.chain) == worker3_id
    end

    test "prevents infinite delegation loops (max 10 levels)" do
      # Try to create 11-level deep chain
      user_ids = for _i <- 1..11, do: Ecto.UUID.generate()

      assert {:error, :delegation_chain_too_deep} = DelegationChain.new(user_ids)
    end
  end

  describe "edge cases" do
    test "exactly 10 levels is valid" do
      chain_ids = for _i <- 1..10, do: Ecto.UUID.generate()
      assert {:ok, %DelegationChain{}} = DelegationChain.new(chain_ids)
    end

    test "11 levels exceeds maximum" do
      chain_ids = for _i <- 1..11, do: Ecto.UUID.generate()
      assert {:error, :delegation_chain_too_deep} = DelegationChain.new(chain_ids)
    end

    test "handles UUID v4 format" do
      uuid_v4 = Ecto.UUID.generate()
      assert {:ok, %DelegationChain{chain: [^uuid_v4]}} = DelegationChain.new([uuid_v4])
    end

    test "accepts both UUIDs and custom strings in chain" do
      valid_uuid = Ecto.UUID.generate()
      custom_string = "custom-user-id"

      assert {:ok, %DelegationChain{chain: [^valid_uuid, ^custom_string]}} =
               DelegationChain.new([valid_uuid, custom_string])
    end
  end

  describe "pattern matching" do
    test "can pattern match on chain structure" do
      user_id1 = Ecto.UUID.generate()
      user_id2 = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new([user_id1, user_id2])

      result =
        case chain do
          %DelegationChain{chain: [^user_id1, ^user_id2]} -> :matched
          %DelegationChain{} -> :not_matched
        end

      assert result == :matched
    end

    test "can pattern match on chain depth" do
      {:ok, shallow_chain} = DelegationChain.from_delegator(Ecto.UUID.generate())

      chain_ids = for _i <- 1..5, do: Ecto.UUID.generate()
      {:ok, deep_chain} = DelegationChain.new(chain_ids)

      result =
        case DelegationChain.depth(deep_chain) do
          1 -> :shallow
          depth when depth > 3 -> :deep
          _ -> :medium
        end

      assert result == :deep
    end
  end

  describe "performance" do
    test "handles maximum depth chains efficiently" do
      chain_ids = for _i <- 1..10, do: Ecto.UUID.generate()

      start_time = System.monotonic_time(:microsecond)
      result = DelegationChain.new(chain_ids)
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      assert {:ok, %DelegationChain{}} = result
      # Should create in less than 1ms
      assert duration < 1000
    end

    test "appends efficiently" do
      {:ok, chain} = DelegationChain.from_delegator(Ecto.UUID.generate())

      start_time = System.monotonic_time(:microsecond)

      # Append 9 more to reach max depth
      {:ok, final_chain} =
        Enum.reduce(1..9, {:ok, chain}, fn _i, {:ok, acc_chain} ->
          DelegationChain.append(acc_chain, Ecto.UUID.generate())
        end)

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      assert DelegationChain.depth(final_chain) == 10
      # Should complete in less than 10ms
      assert duration < 10_000
    end
  end
end
