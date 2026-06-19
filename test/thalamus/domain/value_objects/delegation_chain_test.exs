defmodule Thalamus.Domain.ValueObjects.DelegationChainTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.DelegationChain

  describe "new/1 with valid inputs" do
    test "creates root delegation chain with nil parent" do
      assert {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      assert chain.parent_token_id == nil
      assert chain.depth == 0
      assert chain.path == []
    end

    test "creates delegation chain with parent" do
      parent_id = "550e8400-e29b-41d4-a716-446655440000"

      assert {:ok, chain} =
               DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      assert chain.parent_token_id == parent_id
      assert chain.depth == 1
      assert chain.path == [parent_id]
    end

    test "creates delegation chain at depth 2" do
      parent1 = "550e8400-e29b-41d4-a716-446655440000"
      parent2 = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"

      assert {:ok, chain} =
               DelegationChain.new(%{
                 parent_token_id: parent2,
                 depth: 2,
                 path: [parent1, parent2]
               })

      assert chain.parent_token_id == parent2
      assert chain.depth == 2
      assert chain.path == [parent1, parent2]
    end

    test "creates delegation chain at maximum depth (4)" do
      path = [
        "550e8400-e29b-41d4-a716-446655440000",
        "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
        "b2c3d4e5-f6a7-4890-bcde-f01234567890",
        "c3d4e5f6-a7b8-4901-cdef-012345678901"
      ]

      assert {:ok, chain} =
               DelegationChain.new(%{
                 parent_token_id: List.last(path),
                 depth: 4,
                 path: path
               })

      assert chain.depth == 4
      assert length(chain.path) == 4
    end
  end

  describe "new/1 with depth validation" do
    test "fails when depth exceeds maximum (5)" do
      path = List.duplicate("550e8400-e29b-41d4-a716-446655440000", 5)

      assert {:error, :max_delegation_depth_exceeded} =
               DelegationChain.new(%{
                 parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
                 depth: 5,
                 path: path
               })
    end

    test "fails when depth is greater than 5" do
      assert {:error, :max_delegation_depth_exceeded} =
               DelegationChain.new(%{
                 parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
                 depth: 10,
                 path: []
               })
    end

    test "fails with negative depth" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: nil, depth: -1, path: []})
    end
  end

  describe "new/1 with path validation" do
    test "fails when depth doesn't match path length" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{
                 parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
                 depth: 2,
                 path: ["550e8400-e29b-41d4-a716-446655440000"]
               })
    end

    test "fails when path contains nil values" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: nil, depth: 1, path: [nil]})
    end

    test "fails when path contains empty strings" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: "", depth: 1, path: [""]})
    end

    test "succeeds when root has empty path" do
      assert {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      assert chain.path == []
    end
  end

  describe "new/1 with invalid inputs" do
    test "fails with missing parent_token_id key" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{depth: 0, path: []})
    end

    test "fails with missing depth key" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: nil, path: []})
    end

    test "fails with missing path key" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: nil, depth: 0})
    end

    test "fails with non-integer depth" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: nil, depth: "0", path: []})
    end

    test "fails with non-list path" do
      assert {:error, :invalid_delegation_chain} =
               DelegationChain.new(%{parent_token_id: nil, depth: 0, path: "not a list"})
    end

    test "fails with nil input" do
      assert {:error, :invalid_delegation_chain} = DelegationChain.new(nil)
    end

    test "fails with non-map input" do
      assert {:error, :invalid_delegation_chain} = DelegationChain.new("not a map")
      assert {:error, :invalid_delegation_chain} = DelegationChain.new([])
      assert {:error, :invalid_delegation_chain} = DelegationChain.new(123)
    end
  end

  describe "exceeds_max_depth?/1" do
    test "returns false for root chain" do
      {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      refute DelegationChain.exceeds_max_depth?(chain)
    end

    test "returns false for depth 1" do
      {:ok, chain} =
        DelegationChain.new(%{
          parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
          depth: 1,
          path: ["550e8400-e29b-41d4-a716-446655440000"]
        })

      refute DelegationChain.exceeds_max_depth?(chain)
    end

    test "returns false for depth 4 (at maximum)" do
      path = List.duplicate("550e8400-e29b-41d4-a716-446655440000", 4)

      {:ok, chain} =
        DelegationChain.new(%{
          parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
          depth: 4,
          path: path
        })

      refute DelegationChain.exceeds_max_depth?(chain)
    end
  end

  describe "root?/1" do
    test "returns true for root chain" do
      {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      assert DelegationChain.root?(chain)
    end

    test "returns false for non-root chain" do
      {:ok, chain} =
        DelegationChain.new(%{
          parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
          depth: 1,
          path: ["550e8400-e29b-41d4-a716-446655440000"]
        })

      refute DelegationChain.root?(chain)
    end
  end

  describe "add_delegation/2" do
    test "adds delegation to root chain" do
      {:ok, root} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      token_id = "550e8400-e29b-41d4-a716-446655440000"

      assert {:ok, new_chain} = DelegationChain.add_delegation(root, token_id)
      assert new_chain.parent_token_id == token_id
      assert new_chain.depth == 1
      assert new_chain.path == [token_id]
    end

    test "adds delegation to existing chain" do
      parent_id = "550e8400-e29b-41d4-a716-446655440000"
      new_id = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"

      {:ok, chain} =
        DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      assert {:ok, new_chain} = DelegationChain.add_delegation(chain, new_id)
      assert new_chain.parent_token_id == new_id
      assert new_chain.depth == 2
      assert new_chain.path == [parent_id, new_id]
    end

    test "fails when adding would exceed maximum depth" do
      path = List.duplicate("550e8400-e29b-41d4-a716-446655440000", 4)

      {:ok, chain} =
        DelegationChain.new(%{
          parent_token_id: "550e8400-e29b-41d4-a716-446655440000",
          depth: 4,
          path: path
        })

      assert {:error, :max_delegation_depth_exceeded} =
               DelegationChain.add_delegation(chain, "new-token-id")
    end
  end

  describe "String.Chars protocol" do
    test "converts root chain to string" do
      {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      assert to_string(chain) == "root (depth: 0)"
    end

    test "converts non-root chain to string" do
      parent_id = "550e8400-e29b-41d4-a716-446655440000"

      {:ok, chain} =
        DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      assert to_string(chain) =~ "depth: 1"
      assert to_string(chain) =~ parent_id
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes root chain to JSON" do
      {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})
      json = Jason.encode!(chain)
      decoded = Jason.decode!(json)

      assert decoded["parent_token_id"] == nil
      assert decoded["depth"] == 0
      assert decoded["path"] == []
    end

    test "encodes non-root chain to JSON" do
      parent_id = "550e8400-e29b-41d4-a716-446655440000"

      {:ok, chain} =
        DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      json = Jason.encode!(chain)
      decoded = Jason.decode!(json)

      assert decoded["parent_token_id"] == parent_id
      assert decoded["depth"] == 1
      assert decoded["path"] == [parent_id]
    end
  end

  describe "equality" do
    test "chains with same values are equal" do
      parent_id = "550e8400-e29b-41d4-a716-446655440000"

      {:ok, chain1} =
        DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      {:ok, chain2} =
        DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      assert chain1 == chain2
    end

    test "chains with different depths are not equal" do
      parent_id = "550e8400-e29b-41d4-a716-446655440000"

      {:ok, chain1} =
        DelegationChain.new(%{parent_token_id: parent_id, depth: 1, path: [parent_id]})

      {:ok, chain2} =
        DelegationChain.new(%{
          parent_token_id: parent_id,
          depth: 2,
          path: [parent_id, parent_id]
        })

      assert chain1 != chain2
    end
  end

  describe "pattern matching" do
    test "can pattern match on struct fields" do
      {:ok, chain} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})

      result =
        case chain do
          %DelegationChain{depth: 0, parent_token_id: nil} -> :root
          %DelegationChain{depth: depth} when depth > 0 -> :delegated
        end

      assert result == :root
    end
  end

  describe "semantic meaning" do
    test "delegation chain tracks token hierarchy" do
      # Root token (e.g., user token)
      {:ok, root} = DelegationChain.new(%{parent_token_id: nil, depth: 0, path: []})

      # First delegation (e.g., to autonomous agent)
      token1 = "token-1"
      {:ok, chain1} = DelegationChain.add_delegation(root, token1)

      # Second delegation (e.g., agent delegates to tool)
      token2 = "token-2"
      {:ok, chain2} = DelegationChain.add_delegation(chain1, token2)

      # Path shows complete delegation history
      assert chain2.path == [token1, token2]
      assert chain2.depth == 2
    end
  end
end
