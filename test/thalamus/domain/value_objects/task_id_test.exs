defmodule Thalamus.Domain.ValueObjects.TaskIdTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.TaskId

  describe "new/1 with valid UUIDs" do
    test "creates TaskId from valid UUID v4 string" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, %TaskId{value: ^uuid}} = TaskId.new(uuid)
    end

    test "creates TaskId from lowercase UUID" do
      uuid = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
      assert {:ok, %TaskId{value: ^uuid}} = TaskId.new(uuid)
    end

    test "creates TaskId from uppercase UUID" do
      uuid_upper = "A1B2C3D4-E5F6-4789-ABCD-EF0123456789"
      uuid_lower = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
      assert {:ok, %TaskId{value: ^uuid_lower}} = TaskId.new(uuid_upper)
    end

    test "creates TaskId from mixed case UUID" do
      uuid_mixed = "A1b2C3d4-E5f6-4789-AbCd-Ef0123456789"
      uuid_lower = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
      assert {:ok, %TaskId{value: ^uuid_lower}} = TaskId.new(uuid_mixed)
    end

    test "accepts UUID without dashes and normalizes it" do
      uuid_no_dashes = "a1b2c3d4e5f64789abcdef0123456789"
      uuid_normalized = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
      assert {:ok, %TaskId{value: ^uuid_normalized}} = TaskId.new(uuid_no_dashes)
    end
  end

  describe "new/1 with invalid UUIDs" do
    test "fails with invalid UUID format" do
      assert {:error, :invalid_task_id} = TaskId.new("not-a-uuid")
      assert {:error, :invalid_task_id} = TaskId.new("12345")
      assert {:error, :invalid_task_id} = TaskId.new("invalid-uuid-format")
    end

    test "fails with UUID that has wrong length" do
      assert {:error, :invalid_task_id} = TaskId.new("550e8400-e29b-41d4-a716")
      assert {:error, :invalid_task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000-extra")
    end

    test "fails with UUID that has invalid characters" do
      assert {:error, :invalid_task_id} = TaskId.new("550e8400-e29b-41d4-a716-44665544000g")
      assert {:error, :invalid_task_id} = TaskId.new("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
    end

    test "fails with empty string" do
      assert {:error, :invalid_task_id} = TaskId.new("")
    end

    test "fails with whitespace string" do
      assert {:error, :invalid_task_id} = TaskId.new("   ")
    end

    test "fails with UUID containing whitespace" do
      assert {:error, :invalid_task_id} = TaskId.new("550e8400-e29b-41d4-a716-446655440000 ")
      assert {:error, :invalid_task_id} = TaskId.new(" 550e8400-e29b-41d4-a716-446655440000")
      assert {:error, :invalid_task_id} = TaskId.new("550e8400 -e29b-41d4-a716-446655440000")
    end
  end

  describe "new/1 with invalid input types" do
    test "fails with nil" do
      assert {:error, :invalid_task_id} = TaskId.new(nil)
    end

    test "fails with integer" do
      assert {:error, :invalid_task_id} = TaskId.new(12345)
      assert {:error, :invalid_task_id} = TaskId.new(0)
    end

    test "fails with float" do
      assert {:error, :invalid_task_id} = TaskId.new(123.45)
    end

    test "fails with boolean" do
      assert {:error, :invalid_task_id} = TaskId.new(true)
      assert {:error, :invalid_task_id} = TaskId.new(false)
    end

    test "fails with atom" do
      assert {:error, :invalid_task_id} = TaskId.new(:task_id)
    end

    test "fails with list" do
      assert {:error, :invalid_task_id} = TaskId.new(["550e8400-e29b-41d4-a716-446655440000"])
    end

    test "fails with map" do
      assert {:error, :invalid_task_id} =
               TaskId.new(%{id: "550e8400-e29b-41d4-a716-446655440000"})
    end
  end

  describe "to_string/1" do
    test "converts TaskId to UUID string" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      assert TaskId.to_string(task_id) == uuid
    end

    test "returns normalized lowercase UUID" do
      uuid_upper = "A1B2C3D4-E5F6-4789-ABCD-EF0123456789"
      uuid_lower = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
      {:ok, task_id} = TaskId.new(uuid_upper)
      assert TaskId.to_string(task_id) == uuid_lower
    end
  end

  describe "String.Chars protocol" do
    test "implements String.Chars" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      assert to_string(task_id) == uuid
    end

    test "works with string interpolation" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      assert "Task: #{task_id}" == "Task: #{uuid}"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes TaskId to JSON string" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      assert Jason.encode!(task_id) == ~s("#{uuid}")
    end

    test "encodes and decodes roundtrip" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      json = Jason.encode!(task_id)
      decoded_string = Jason.decode!(json)
      assert {:ok, roundtrip_id} = TaskId.new(decoded_string)
      assert roundtrip_id == task_id
    end
  end

  describe "equality and comparison" do
    test "TaskIds with same UUID are equal" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, id1} = TaskId.new(uuid)
      {:ok, id2} = TaskId.new(uuid)
      assert id1 == id2
    end

    test "TaskIds with same UUID in different cases are equal" do
      uuid_lower = "550e8400-e29b-41d4-a716-446655440000"
      uuid_upper = "550E8400-E29B-41D4-A716-446655440000"
      {:ok, id1} = TaskId.new(uuid_lower)
      {:ok, id2} = TaskId.new(uuid_upper)
      assert id1 == id2
    end

    test "TaskIds with different UUIDs are not equal" do
      {:ok, id1} = TaskId.new("550e8400-e29b-41d4-a716-446655440000")
      {:ok, id2} = TaskId.new("a1b2c3d4-e5f6-4789-abcd-ef0123456789")
      assert id1 != id2
    end
  end

  describe "pattern matching" do
    test "can pattern match on value" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)

      result =
        case task_id do
          %TaskId{value: ^uuid} -> :matched
          _ -> :not_matched
        end

      assert result == :matched
    end
  end

  describe "semantic meaning" do
    test "TaskId represents a unique task identifier" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      # In production, TaskId is used to track agent delegation chains
      assert task_id.value == uuid
    end

    test "TaskId is immutable" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      {:ok, task_id} = TaskId.new(uuid)
      # Structs in Elixir are immutable by design
      # Any "modification" creates a new struct
      modified = %{task_id | value: "different-uuid"}
      assert task_id.value == uuid
      assert modified.value == "different-uuid"
      assert task_id != modified
    end
  end

  describe "edge cases" do
    test "handles UUID with all zeros" do
      uuid = "00000000-0000-0000-0000-000000000000"
      assert {:ok, %TaskId{value: ^uuid}} = TaskId.new(uuid)
    end

    test "handles UUID with all Fs" do
      uuid_upper = "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
      uuid_lower = "ffffffff-ffff-ffff-ffff-ffffffffffff"
      assert {:ok, %TaskId{value: ^uuid_lower}} = TaskId.new(uuid_upper)
    end

    test "rejects UUID with curly braces" do
      assert {:error, :invalid_task_id} = TaskId.new("{550e8400-e29b-41d4-a716-446655440000}")
    end

    test "rejects URN format UUID" do
      assert {:error, :invalid_task_id} =
               TaskId.new("urn:uuid:550e8400-e29b-41d4-a716-446655440000")
    end
  end
end
