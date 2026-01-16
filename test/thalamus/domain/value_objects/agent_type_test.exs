defmodule Thalamus.Domain.ValueObjects.AgentTypeTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.AgentType

  describe "new/1 with atoms" do
    test "creates autonomous agent type" do
      assert {:ok, %AgentType{value: :autonomous}} = AgentType.new(:autonomous)
    end

    test "creates supervised agent type" do
      assert {:ok, %AgentType{value: :supervised}} = AgentType.new(:supervised)
    end

    test "creates ephemeral agent type" do
      assert {:ok, %AgentType{value: :ephemeral}} = AgentType.new(:ephemeral)
    end

    test "fails with invalid atom" do
      assert {:error, :invalid_agent_type} = AgentType.new(:invalid)
      assert {:error, :invalid_agent_type} = AgentType.new(:manual)
      assert {:error, :invalid_agent_type} = AgentType.new(:hybrid)
    end
  end

  describe "new/1 with strings" do
    test "creates autonomous from lowercase string" do
      assert {:ok, %AgentType{value: :autonomous}} = AgentType.new("autonomous")
    end

    test "creates supervised from lowercase string" do
      assert {:ok, %AgentType{value: :supervised}} = AgentType.new("supervised")
    end

    test "creates ephemeral from lowercase string" do
      assert {:ok, %AgentType{value: :ephemeral}} = AgentType.new("ephemeral")
    end

    test "creates autonomous from uppercase string" do
      assert {:ok, %AgentType{value: :autonomous}} = AgentType.new("AUTONOMOUS")
    end

    test "creates supervised from mixed case string" do
      assert {:ok, %AgentType{value: :supervised}} = AgentType.new("Supervised")
    end

    test "creates ephemeral from uppercase string" do
      assert {:ok, %AgentType{value: :ephemeral}} = AgentType.new("EPHEMERAL")
    end

    test "fails with invalid string" do
      assert {:error, :invalid_agent_type} = AgentType.new("invalid")
      assert {:error, :invalid_agent_type} = AgentType.new("manual")
      assert {:error, :invalid_agent_type} = AgentType.new("robot")
    end

    test "fails with empty string" do
      assert {:error, :invalid_agent_type} = AgentType.new("")
    end

    test "fails with whitespace string" do
      assert {:error, :invalid_agent_type} = AgentType.new("  ")
    end
  end

  describe "new/1 with invalid input types" do
    test "fails with nil" do
      assert {:error, :invalid_agent_type} = AgentType.new(nil)
    end

    test "fails with integer" do
      assert {:error, :invalid_agent_type} = AgentType.new(1)
      assert {:error, :invalid_agent_type} = AgentType.new(0)
    end

    test "fails with boolean" do
      assert {:error, :invalid_agent_type} = AgentType.new(true)
      assert {:error, :invalid_agent_type} = AgentType.new(false)
    end

    test "fails with list" do
      assert {:error, :invalid_agent_type} = AgentType.new([:autonomous])
    end

    test "fails with map" do
      assert {:error, :invalid_agent_type} = AgentType.new(%{type: "autonomous"})
    end
  end

  describe "to_string/1" do
    test "converts autonomous to string" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      assert AgentType.to_string(agent_type) == "autonomous"
    end

    test "converts supervised to string" do
      {:ok, agent_type} = AgentType.new(:supervised)
      assert AgentType.to_string(agent_type) == "supervised"
    end

    test "converts ephemeral to string" do
      {:ok, agent_type} = AgentType.new(:ephemeral)
      assert AgentType.to_string(agent_type) == "ephemeral"
    end
  end

  describe "String.Chars protocol" do
    test "implements String.Chars for autonomous" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      assert to_string(agent_type) == "autonomous"
    end

    test "implements String.Chars for supervised" do
      {:ok, agent_type} = AgentType.new(:supervised)
      assert to_string(agent_type) == "supervised"
    end

    test "implements String.Chars for ephemeral" do
      {:ok, agent_type} = AgentType.new(:ephemeral)
      assert to_string(agent_type) == "ephemeral"
    end

    test "works with string interpolation" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      assert "Type: #{agent_type}" == "Type: autonomous"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes autonomous to JSON string" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      assert Jason.encode!(agent_type) == ~s("autonomous")
    end

    test "encodes supervised to JSON string" do
      {:ok, agent_type} = AgentType.new(:supervised)
      assert Jason.encode!(agent_type) == ~s("supervised")
    end

    test "encodes ephemeral to JSON string" do
      {:ok, agent_type} = AgentType.new(:ephemeral)
      assert Jason.encode!(agent_type) == ~s("ephemeral")
    end

    test "encodes and decodes roundtrip" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      json = Jason.encode!(agent_type)
      decoded_string = Jason.decode!(json)
      assert {:ok, roundtrip_type} = AgentType.new(decoded_string)
      assert roundtrip_type == agent_type
    end
  end

  describe "equality and comparison" do
    test "agent types with same value are equal" do
      {:ok, type1} = AgentType.new(:autonomous)
      {:ok, type2} = AgentType.new("autonomous")
      assert type1 == type2
    end

    test "agent types with different values are not equal" do
      {:ok, type1} = AgentType.new(:autonomous)
      {:ok, type2} = AgentType.new(:supervised)
      assert type1 != type2
    end

    test "autonomous vs supervised vs ephemeral" do
      {:ok, autonomous} = AgentType.new(:autonomous)
      {:ok, supervised} = AgentType.new(:supervised)
      {:ok, ephemeral} = AgentType.new(:ephemeral)

      assert autonomous != supervised
      assert autonomous != ephemeral
      assert supervised != ephemeral
    end
  end

  describe "valid_types/0" do
    test "returns all valid agent types" do
      valid_types = AgentType.valid_types()
      assert :autonomous in valid_types
      assert :supervised in valid_types
      assert :ephemeral in valid_types
      assert length(valid_types) == 3
    end
  end

  describe "edge cases" do
    test "string with leading whitespace fails" do
      assert {:error, :invalid_agent_type} = AgentType.new(" autonomous")
    end

    test "string with trailing whitespace fails" do
      assert {:error, :invalid_agent_type} = AgentType.new("autonomous ")
    end

    test "string with internal whitespace fails" do
      assert {:error, :invalid_agent_type} = AgentType.new("auto nomous")
    end

    test "unicode characters fail" do
      assert {:error, :invalid_agent_type} = AgentType.new("autónomo")
    end

    test "special characters fail" do
      assert {:error, :invalid_agent_type} = AgentType.new("autonomous!")
      assert {:error, :invalid_agent_type} = AgentType.new("supervised?")
      assert {:error, :invalid_agent_type} = AgentType.new("ephemeral#")
    end
  end

  describe "pattern matching" do
    test "can pattern match on value" do
      {:ok, agent_type} = AgentType.new(:autonomous)

      result =
        case agent_type do
          %AgentType{value: :autonomous} -> :matched_autonomous
          %AgentType{value: :supervised} -> :matched_supervised
          %AgentType{value: :ephemeral} -> :matched_ephemeral
        end

      assert result == :matched_autonomous
    end
  end

  describe "semantic meaning" do
    test "autonomous indicates fully independent operation" do
      {:ok, autonomous} = AgentType.new(:autonomous)
      # In production, autonomous agents operate without human oversight
      assert autonomous.value == :autonomous
    end

    test "supervised indicates human oversight required" do
      {:ok, supervised} = AgentType.new(:supervised)
      # In production, supervised agents require human approval for actions
      assert supervised.value == :supervised
    end

    test "ephemeral indicates short-lived task-specific agent" do
      {:ok, ephemeral} = AgentType.new(:ephemeral)
      # In production, ephemeral agents are auto-revoked after task completion
      assert ephemeral.value == :ephemeral
    end
  end
end
