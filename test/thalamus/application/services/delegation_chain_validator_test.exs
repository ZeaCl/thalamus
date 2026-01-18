defmodule Thalamus.Application.Services.DelegationChainValidatorTest do
  use ExUnit.Case, async: true
  import Mox

  alias Thalamus.Application.Services.DelegationChainValidator
  alias Thalamus.Domain.ValueObjects.DelegationChain

  # Define mock for UserRepository
  Mox.defmock(MockUserRepository, for: Thalamus.Application.Ports.UserRepository)

  setup :verify_on_exit!

  describe "validate_depth/1" do
    test "returns :ok for chain within depth limit" do
      user_ids = Enum.map(1..5, fn _ -> Ecto.UUID.generate() end)
      {:ok, chain} = DelegationChain.new(user_ids)

      assert :ok = DelegationChainValidator.validate_depth(chain)
    end

    test "returns :ok for chain at maximum depth (10)" do
      user_ids = Enum.map(1..10, fn _ -> Ecto.UUID.generate() end)
      {:ok, chain} = DelegationChain.new(user_ids)

      assert :ok = DelegationChainValidator.validate_depth(chain)
    end

    test "returns error for chain exceeding depth limit" do
      user_ids = Enum.map(1..11, fn _ -> Ecto.UUID.generate() end)

      # DelegationChain.new itself validates depth, so this will fail
      assert {:error, :delegation_chain_too_deep} = DelegationChain.new(user_ids)
    end

    test "returns :ok for root (empty) chain" do
      {:ok, chain} = DelegationChain.root()

      assert :ok = DelegationChainValidator.validate_depth(chain)
    end
  end

  describe "validate_no_circular_delegation/1" do
    test "returns :ok for chain with unique users" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()
      user_id_3 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2, user_id_3])

      assert :ok = DelegationChainValidator.validate_no_circular_delegation(chain)
    end

    test "returns error for chain with duplicate user" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      # Create chain with duplicate (user_id_1 appears twice)
      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2, user_id_1])

      assert {:error, :circular_delegation} =
               DelegationChainValidator.validate_no_circular_delegation(chain)
    end

    test "returns :ok for single-user chain" do
      user_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.from_delegator(user_id)

      assert :ok = DelegationChainValidator.validate_no_circular_delegation(chain)
    end
  end

  describe "validate_user_ids_format/1" do
    test "returns :ok for chain with valid UUIDs" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      assert :ok = DelegationChainValidator.validate_user_ids_format(chain)
    end

    test "returns :ok for root chain" do
      {:ok, chain} = DelegationChain.root()

      assert :ok = DelegationChainValidator.validate_user_ids_format(chain)
    end
  end

  describe "validate_users_exist/2" do
    test "returns :ok when all users exist" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch query returning both users
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1},
           user_id_2 => %{id: user_id_2}
         }}
      end)

      deps = %{user_repository: MockUserRepository}

      assert :ok = DelegationChainValidator.validate_users_exist(chain, deps)
    end

    test "returns error when user not found" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch query returning only user_id_1 (user_id_2 not found)
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok, %{user_id_1 => %{id: user_id_1}}}
      end)

      deps = %{user_repository: MockUserRepository}

      assert {:error, {:user_not_found, ^user_id_2}} =
               DelegationChainValidator.validate_users_exist(chain, deps)
    end

    test "returns :ok for empty chain" do
      {:ok, chain} = DelegationChain.root()

      deps = %{user_repository: MockUserRepository}

      assert :ok = DelegationChainValidator.validate_users_exist(chain, deps)
    end
  end

  describe "validate_users_active/2" do
    test "returns :ok when all users are active (status field)" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch query returning both active users
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1, status: :active},
           user_id_2 => %{id: user_id_2, status: :active}
         }}
      end)

      deps = %{user_repository: MockUserRepository}

      assert :ok = DelegationChainValidator.validate_users_active(chain, deps)
    end

    test "returns :ok when all users are active (is_active field)" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch query returning both active users
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1, is_active: true},
           user_id_2 => %{id: user_id_2, is_active: true}
         }}
      end)

      deps = %{user_repository: MockUserRepository}

      assert :ok = DelegationChainValidator.validate_users_active(chain, deps)
    end

    test "returns error when user is inactive" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch query with one inactive user
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1, status: :active},
           user_id_2 => %{id: user_id_2, status: :inactive}
         }}
      end)

      deps = %{user_repository: MockUserRepository}

      assert {:error, {:user_inactive, ^user_id_2}} =
               DelegationChainValidator.validate_users_active(chain, deps)
    end

    test "returns :ok for empty chain" do
      {:ok, chain} = DelegationChain.root()

      deps = %{user_repository: MockUserRepository}

      assert :ok = DelegationChainValidator.validate_users_active(chain, deps)
    end
  end

  describe "validate/2 - full validation" do
    test "returns :ok for valid delegation chain" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch queries for validate_users_exist and validate_users_active
      MockUserRepository
      |> expect(:find_by_ids, 2, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1, status: :active},
           user_id_2 => %{id: user_id_2, status: :active}
         }}
      end)

      deps = %{user_repository: MockUserRepository}

      assert :ok = DelegationChainValidator.validate(chain, deps)
    end

    test "returns error for chain exceeding depth" do
      user_ids = Enum.map(1..11, fn _ -> Ecto.UUID.generate() end)

      # DelegationChain.new itself validates depth during construction
      assert {:error, :delegation_chain_too_deep} = DelegationChain.new(user_ids)
    end

    test "returns error for circular delegation" do
      user_id = Ecto.UUID.generate()
      {:ok, chain} = DelegationChain.new([user_id, user_id])

      deps = %{user_repository: MockUserRepository}

      assert {:error, :circular_delegation} = DelegationChainValidator.validate(chain, deps)
    end

    test "returns error when user not found" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # Mock batch query with user_id_2 missing
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok, %{user_id_1 => %{id: user_id_1, status: :active}}}
      end)

      deps = %{user_repository: MockUserRepository}

      assert {:error, {:user_not_found, ^user_id_2}} =
               DelegationChainValidator.validate(chain, deps)
    end

    test "returns error when user is inactive" do
      user_id_1 = Ecto.UUID.generate()
      user_id_2 = Ecto.UUID.generate()

      {:ok, chain} = DelegationChain.new([user_id_1, user_id_2])

      # First batch query for validate_users_exist (both users found)
      # Second batch query for validate_users_active (user_id_2 is inactive)
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1, status: :active},
           user_id_2 => %{id: user_id_2, status: :active}
         }}
      end)
      |> expect(:find_by_ids, fn [^user_id_1, ^user_id_2] ->
        {:ok,
         %{
           user_id_1 => %{id: user_id_1, status: :active},
           user_id_2 => %{id: user_id_2, status: :inactive}
         }}
      end)

      deps = %{user_repository: MockUserRepository}

      assert {:error, {:user_inactive, ^user_id_2}} =
               DelegationChainValidator.validate(chain, deps)
    end
  end

  describe "build_chain/2" do
    test "builds a valid delegation chain from user ID" do
      user_id = Ecto.UUID.generate()

      assert {:ok, chain} = DelegationChainValidator.build_chain(user_id, nil)
      assert chain.chain == [user_id]
    end

    test "builds and validates chain when deps provided" do
      user_id = Ecto.UUID.generate()

      # Mock batch queries for validate_users_exist and validate_users_active
      MockUserRepository
      |> expect(:find_by_ids, 2, fn [^user_id] ->
        {:ok, %{user_id => %{id: user_id, status: :active}}}
      end)

      deps = %{user_repository: MockUserRepository}

      assert {:ok, chain} = DelegationChainValidator.build_chain(user_id, deps)
      assert chain.chain == [user_id]
    end

    test "returns error when validation fails" do
      user_id = Ecto.UUID.generate()

      # Mock batch query with user not found
      MockUserRepository
      |> expect(:find_by_ids, fn [^user_id] -> {:ok, %{}} end)

      deps = %{user_repository: MockUserRepository}

      assert {:error, {:user_not_found, ^user_id}} =
               DelegationChainValidator.build_chain(user_id, deps)
    end
  end
end
