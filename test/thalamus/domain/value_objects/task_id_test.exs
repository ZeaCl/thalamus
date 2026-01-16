defmodule Thalamus.Domain.ValueObjects.TaskIdTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.TaskId

  describe "new/1 with valid inputs" do
    test "creates task ID with alphanumeric characters" do
      assert {:ok, %TaskId{value: "task123"}} = TaskId.new("task123")
    end

    test "creates task ID with hyphens" do
      assert {:ok, %TaskId{value: "task-123"}} = TaskId.new("task-123")
    end

    test "creates task ID with underscores" do
      assert {:ok, %TaskId{value: "task_123"}} = TaskId.new("task_123")
    end

    test "creates task ID with mixed valid characters" do
      assert {:ok, %TaskId{value: "task_abc-123_XYZ"}} = TaskId.new("task_abc-123_XYZ")
    end

    test "creates task ID with minimum length (1 char)" do
      assert {:ok, %TaskId{value: "a"}} = TaskId.new("a")
      assert {:ok, %TaskId{value: "1"}} = TaskId.new("1")
      assert {:ok, %TaskId{value: "_"}} = TaskId.new("_")
      assert {:ok, %TaskId{value: "-"}} = TaskId.new("-")
    end

    test "creates task ID with maximum length (255 chars)" do
      max_id = String.duplicate("a", 255)
      assert {:ok, %TaskId{value: ^max_id}} = TaskId.new(max_id)
    end

    test "creates task ID with uppercase letters" do
      assert {:ok, %TaskId{value: "TASK_ABC"}} = TaskId.new("TASK_ABC")
    end

    test "creates task ID with numbers only" do
      assert {:ok, %TaskId{value: "123456789"}} = TaskId.new("123456789")
    end

    test "creates task ID with UUID-like format" do
      assert {:ok, %TaskId{value: "550e8400-e29b-41d4-a716-446655440000"}} =
               TaskId.new("550e8400-e29b-41d4-a716-446655440000")
    end
  end

  describe "new/1 with invalid inputs" do
    test "fails with empty string" do
      assert {:error, :task_id_too_short} = TaskId.new("")
    end

    test "fails with nil" do
      assert {:error, :invalid_task_id} = TaskId.new(nil)
    end

    test "fails with non-string input" do
      assert {:error, :invalid_task_id} = TaskId.new(12345)
      assert {:error, :invalid_task_id} = TaskId.new(:atom)
      assert {:error, :invalid_task_id} = TaskId.new(%{})
      assert {:error, :invalid_task_id} = TaskId.new([:list])
    end

    test "fails with too long string (> 255 chars)" do
      too_long = String.duplicate("a", 256)
      assert {:error, :task_id_too_long} = TaskId.new(too_long)
    end

    test "fails with invalid characters (spaces)" do
      assert {:error, :invalid_task_id_format} = TaskId.new("task 123")
    end

    test "fails with invalid characters (special chars)" do
      assert {:error, :invalid_task_id_format} = TaskId.new("task@123")
      assert {:error, :invalid_task_id_format} = TaskId.new("task#123")
      assert {:error, :invalid_task_id_format} = TaskId.new("task$123")
      assert {:error, :invalid_task_id_format} = TaskId.new("task%123")
      assert {:error, :invalid_task_id_format} = TaskId.new("task&123")
      assert {:error, :invalid_task_id_format} = TaskId.new("task*123")
    end

    test "fails with invalid characters (dots)" do
      assert {:error, :invalid_task_id_format} = TaskId.new("task.123")
    end

    test "fails with invalid characters (slashes)" do
      assert {:error, :invalid_task_id_format} = TaskId.new("task/123")
      assert {:error, :invalid_task_id_format} = TaskId.new("task\\123")
    end

    test "fails with invalid characters (unicode)" do
      assert {:error, :invalid_task_id_format} = TaskId.new("task_café")
      assert {:error, :invalid_task_id_format} = TaskId.new("task_测试")
      assert {:error, :invalid_task_id_format} = TaskId.new("task_🚀")
    end

    test "fails with leading whitespace" do
      assert {:error, :invalid_task_id_format} = TaskId.new(" task123")
    end

    test "fails with trailing whitespace" do
      assert {:error, :invalid_task_id_format} = TaskId.new("task123 ")
    end
  end

  describe "to_string/1" do
    test "converts task ID to string" do
      {:ok, task_id} = TaskId.new("task_abc-123")
      assert TaskId.to_string(task_id) == "task_abc-123"
    end

    test "preserves case" do
      {:ok, task_id} = TaskId.new("Task_ABC-123")
      assert TaskId.to_string(task_id) == "Task_ABC-123"
    end
  end

  describe "String.Chars protocol" do
    test "implements String.Chars protocol" do
      {:ok, task_id} = TaskId.new("task_123")
      assert to_string(task_id) == "task_123"
    end

    test "works with string interpolation" do
      {:ok, task_id} = TaskId.new("task_abc")
      assert "Task: #{task_id}" == "Task: task_abc"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes to JSON string" do
      {:ok, task_id} = TaskId.new("task_123")
      assert Jason.encode!(task_id) == ~s("task_123")
    end

    test "encodes and decodes roundtrip" do
      {:ok, task_id} = TaskId.new("task_abc-123")
      json = Jason.encode!(task_id)
      decoded_string = Jason.decode!(json)
      assert {:ok, roundtrip_id} = TaskId.new(decoded_string)
      assert roundtrip_id == task_id
    end
  end

  describe "equality and comparison" do
    test "task IDs with same value are equal" do
      {:ok, id1} = TaskId.new("task_123")
      {:ok, id2} = TaskId.new("task_123")
      assert id1 == id2
    end

    test "task IDs with different values are not equal" do
      {:ok, id1} = TaskId.new("task_123")
      {:ok, id2} = TaskId.new("task_456")
      assert id1 != id2
    end

    test "task IDs are case-sensitive" do
      {:ok, id1} = TaskId.new("task_ABC")
      {:ok, id2} = TaskId.new("task_abc")
      assert id1 != id2
    end
  end

  describe "real-world task ID patterns" do
    test "accepts common UUID format" do
      uuid = "550e8400-e29b-41d4-a716-446655440000"
      assert {:ok, %TaskId{value: ^uuid}} = TaskId.new(uuid)
    end

    test "accepts Anthropic-style prefixed IDs" do
      assert {:ok, %TaskId{}} = TaskId.new("task_abc123xyz")
      assert {:ok, %TaskId{}} = TaskId.new("run_xyz789")
      assert {:ok, %TaskId{}} = TaskId.new("job_123abc")
    end

    test "accepts GitHub Actions style IDs" do
      assert {:ok, %TaskId{}} = TaskId.new("workflow-run-12345")
      assert {:ok, %TaskId{}} = TaskId.new("job-2024-01-15-abc")
    end

    test "accepts timestamp-based IDs" do
      assert {:ok, %TaskId{}} = TaskId.new("20240115-123456-abc")
      assert {:ok, %TaskId{}} = TaskId.new("1705334400-task-xyz")
    end

    test "accepts composite IDs" do
      assert {:ok, %TaskId{}} = TaskId.new("user_123-task_456-run_789")
      assert {:ok, %TaskId{}} = TaskId.new("org_abc-project_xyz-workflow_001")
    end
  end

  describe "edge cases" do
    test "accepts single character" do
      assert {:ok, %TaskId{value: "a"}} = TaskId.new("a")
      assert {:ok, %TaskId{value: "1"}} = TaskId.new("1")
      assert {:ok, %TaskId{value: "-"}} = TaskId.new("-")
      assert {:ok, %TaskId{value: "_"}} = TaskId.new("_")
    end

    test "accepts all hyphens" do
      assert {:ok, %TaskId{value: "---"}} = TaskId.new("---")
    end

    test "accepts all underscores" do
      assert {:ok, %TaskId{value: "___"}} = TaskId.new("___")
    end

    test "accepts mixed hyphens and underscores" do
      assert {:ok, %TaskId{value: "-_-_-"}} = TaskId.new("-_-_-")
    end

    test "exactly 255 characters is valid" do
      exactly_255 = String.duplicate("a", 255)
      assert {:ok, %TaskId{value: ^exactly_255}} = TaskId.new(exactly_255)
    end

    test "256 characters is invalid" do
      exactly_256 = String.duplicate("a", 256)
      assert {:error, :task_id_too_long} = TaskId.new(exactly_256)
    end
  end

  describe "pattern matching" do
    test "can pattern match on value" do
      {:ok, task_id} = TaskId.new("task_123")

      result =
        case task_id do
          %TaskId{value: "task_123"} -> :matched
          %TaskId{} -> :not_matched
        end

      assert result == :matched
    end

    test "can pattern match on different task IDs" do
      {:ok, task_id} = TaskId.new("workflow_xyz")

      result =
        case task_id do
          %TaskId{value: "task_" <> _} -> :is_task
          %TaskId{value: "workflow_" <> _} -> :is_workflow
          %TaskId{} -> :is_other
        end

      assert result == :is_workflow
    end
  end

  describe "performance" do
    test "validates large number of task IDs efficiently" do
      start_time = System.monotonic_time(:microsecond)

      # Validate 1000 task IDs
      results =
        for i <- 1..1000 do
          TaskId.new("task_#{i}")
        end

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      # Should complete in reasonable time (less than 100ms)
      assert duration < 100_000
      assert Enum.all?(results, fn result -> match?({:ok, %TaskId{}}, result) end)
    end

    test "handles maximum length IDs efficiently" do
      max_id = String.duplicate("a", 255)

      start_time = System.monotonic_time(:microsecond)
      result = TaskId.new(max_id)
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      assert {:ok, %TaskId{}} = result
      # Should validate in less than 1ms
      assert duration < 1000
    end
  end
end
