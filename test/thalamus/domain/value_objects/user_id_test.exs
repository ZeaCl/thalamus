defmodule Thalamus.Domain.ValueObjects.UserIdTest do
  use ExUnit.Case, async: false
  doctest Thalamus.Domain.ValueObjects.UserId

  alias Thalamus.Domain.ValueObjects.UserId

  describe "new/1" do
    test "creates valid user ID with string input" do
      assert {:ok, %UserId{value: "user_12345"}} = UserId.new("user_12345")
    end

    test "creates valid user ID with UUID format" do
      uuid = "user_550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, %UserId{value: ^uuid}} = UserId.new(uuid)
    end

    test "creates valid user ID with minimum length" do
      assert {:ok, %UserId{value: "abc"}} = UserId.new("abc")
    end

    test "creates valid user ID with maximum length" do
      # Total 100 chars
      long_id = "user_" <> String.duplicate("a", 95)
      assert {:ok, %UserId{value: ^long_id}} = UserId.new(long_id)
    end

    test "fails with empty string" do
      assert {:error, :invalid_user_id} = UserId.new("")
    end

    test "fails with nil" do
      assert {:error, :invalid_user_id} = UserId.new(nil)
    end

    test "fails with non-string input" do
      assert {:error, :invalid_user_id} = UserId.new(12345)
      assert {:error, :invalid_user_id} = UserId.new(:atom)
      assert {:error, :invalid_user_id} = UserId.new(%{})
    end

    test "fails with too short string" do
      assert {:error, :user_id_too_short} = UserId.new("ab")
    end

    test "fails with too long string" do
      long_id = String.duplicate("a", 101)
      assert {:error, :user_id_too_long} = UserId.new(long_id)
    end

    test "fails with invalid characters" do
      assert {:error, :invalid_user_id_format} = UserId.new("user@123")
      assert {:error, :invalid_user_id_format} = UserId.new("user 123")
      assert {:error, :invalid_user_id_format} = UserId.new("user#123")
      assert {:error, :invalid_user_id_format} = UserId.new("user.123")
    end

    test "allows valid characters: alphanumeric, underscore, and dash" do
      assert {:ok, %UserId{}} = UserId.new("user_123")
      assert {:ok, %UserId{}} = UserId.new("user-123")
      assert {:ok, %UserId{}} = UserId.new("ABC123def")
      assert {:ok, %UserId{}} = UserId.new("123456789")
    end
  end

  describe "generate/0" do
    test "generates a valid user ID" do
      assert {:ok, %UserId{value: value}} = UserId.generate()
      assert String.starts_with?(value, "user_")
      # Should be longer than just "user_"
      assert String.length(value) > 10
    end

    test "generates unique user IDs" do
      assert {:ok, user_id1} = UserId.generate()
      assert {:ok, user_id2} = UserId.generate()
      assert user_id1.value != user_id2.value
    end

    test "generated ID passes validation" do
      assert {:ok, %UserId{value: value}} = UserId.generate()
      assert {:ok, %UserId{}} = UserId.new(value)
    end
  end

  describe "to_string/1" do
    test "converts user ID to string" do
      user_id = %UserId{value: "user_12345"}
      assert UserId.to_string(user_id) == "user_12345"
    end
  end

  describe "from_string/1" do
    test "creates user ID from valid string" do
      assert {:ok, %UserId{value: "user_12345"}} = UserId.from_string("user_12345")
    end

    test "fails with invalid string" do
      assert {:error, :user_id_too_short} = UserId.from_string("ab")
    end
  end

  describe "String.Chars protocol" do
    test "implements String.Chars protocol" do
      user_id = %UserId{value: "user_12345"}
      assert to_string(user_id) == "user_12345"
    end

    test "works with string interpolation" do
      user_id = %UserId{value: "user_12345"}
      assert "User: #{user_id}" == "User: user_12345"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes to JSON string" do
      user_id = %UserId{value: "user_12345"}
      assert Jason.encode!(user_id) == ~s("user_12345")
    end

    test "decodes from JSON requires explicit conversion" do
      json = ~s("user_12345")
      decoded_string = Jason.decode!(json)
      assert {:ok, %UserId{value: "user_12345"}} = UserId.from_string(decoded_string)
    end
  end

  describe "equality and comparison" do
    test "user IDs with same value are equal" do
      {:ok, user_id1} = UserId.new("user_12345")
      {:ok, user_id2} = UserId.new("user_12345")
      assert user_id1 == user_id2
    end

    test "user IDs with different values are not equal" do
      {:ok, user_id1} = UserId.new("user_12345")
      {:ok, user_id2} = UserId.new("user_67890")
      assert user_id1 != user_id2
    end
  end

  describe "edge cases" do
    test "handles whitespace in input" do
      # Our implementation should trim whitespace
      # (This test might need adjustment based on actual implementation)
      assert {:error, :invalid_user_id_format} = UserId.new(" user_123 ")
    end

    test "handles unicode characters" do
      assert {:error, :invalid_user_id_format} = UserId.new("user_café")
      assert {:error, :invalid_user_id_format} = UserId.new("user_测试")
    end

    test "handles very specific valid patterns" do
      assert {:ok, %UserId{}} = UserId.new("a-b_c123")
      assert {:ok, %UserId{}} = UserId.new("123-456_789")
    end
  end

  describe "performance" do
    test "validates large number of user IDs efficiently" do
      start_time = System.monotonic_time(:microsecond)

      # Generate and validate 1000 user IDs
      results =
        for _i <- 1..1000 do
          {:ok, user_id} = UserId.generate()
          UserId.new(user_id.value)
        end

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Should complete in reasonable time (less than 1 second)
      assert duration < 1_000_000
      assert Enum.all?(results, fn result -> match?({:ok, %UserId{}}, result) end)
    end
  end
end
