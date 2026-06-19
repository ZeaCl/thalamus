defmodule Thalamus.Domain.ValueObjects.AgentTypeTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.AgentType

  describe "new/1 with atoms" do
    test "creates autonomous agent type" do
      assert {:ok, %AgentType{value: :autonomous}} = AgentType.new(:autonomous)
    end

    test "creates supervisor agent type" do
      assert {:ok, %AgentType{value: :supervisor}} = AgentType.new(:supervisor)
    end

    test "creates tool agent type" do
      assert {:ok, %AgentType{value: :tool}} = AgentType.new(:tool)
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

    test "creates supervisor from lowercase string" do
      assert {:ok, %AgentType{value: :supervisor}} = AgentType.new("supervisor")
    end

    test "creates tool from lowercase string" do
      assert {:ok, %AgentType{value: :tool}} = AgentType.new("tool")
    end

    test "creates autonomous from uppercase string" do
      assert {:ok, %AgentType{value: :autonomous}} = AgentType.new("AUTONOMOUS")
    end

    test "creates supervisor from mixed case string" do
      assert {:ok, %AgentType{value: :supervisor}} = AgentType.new("Supervisor")
    end

    test "creates tool from uppercase string" do
      assert {:ok, %AgentType{value: :tool}} = AgentType.new("TOOL")
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

    test "converts supervisor to string" do
      {:ok, agent_type} = AgentType.new(:supervisor)
      assert AgentType.to_string(agent_type) == "supervisor"
    end

    test "converts tool to string" do
      {:ok, agent_type} = AgentType.new(:tool)
      assert AgentType.to_string(agent_type) == "tool"
    end
  end

  describe "String.Chars protocol" do
    test "implements String.Chars for autonomous" do
      {:ok, agent_type} = AgentType.new(:autonomous)
      assert to_string(agent_type) == "autonomous"
    end

    test "implements String.Chars for supervisor" do
      {:ok, agent_type} = AgentType.new(:supervisor)
      assert to_string(agent_type) == "supervisor"
    end

    test "implements String.Chars for tool" do
      {:ok, agent_type} = AgentType.new(:tool)
      assert to_string(agent_type) == "tool"
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

    test "encodes supervisor to JSON string" do
      {:ok, agent_type} = AgentType.new(:supervisor)
      assert Jason.encode!(agent_type) == ~s("supervisor")
    end

    test "encodes tool to JSON string" do
      {:ok, agent_type} = AgentType.new(:tool)
      assert Jason.encode!(agent_type) == ~s("tool")
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
      {:ok, type2} = AgentType.new(:supervisor)
      assert type1 != type2
    end

    test "autonomous vs supervisor vs tool" do
      {:ok, autonomous} = AgentType.new(:autonomous)
      {:ok, supervisor} = AgentType.new(:supervisor)
      {:ok, tool} = AgentType.new(:tool)

      assert autonomous != supervisor
      assert autonomous != tool
      assert supervisor != tool
    end
  end

  describe "valid_types/0" do
    test "returns all valid agent types" do
      valid_types = AgentType.valid_types()
      assert :autonomous in valid_types
      assert :supervisor in valid_types
      assert :tool in valid_types
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
      assert {:error, :invalid_agent_type} = AgentType.new("supervisor?")
      assert {:error, :invalid_agent_type} = AgentType.new("tool#")
    end
  end

  describe "pattern matching" do
    test "can pattern match on value" do
      {:ok, agent_type} = AgentType.new(:autonomous)

      result =
        case agent_type do
          %AgentType{value: :autonomous} -> :matched_autonomous
          %AgentType{value: :supervisor} -> :matched_supervised
          %AgentType{value: :tool} -> :matched_ephemeral
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

    test "supervisor indicates agents that coordinate other agents" do
      {:ok, supervisor} = AgentType.new(:supervisor)
      # In production, supervisor agents coordinate and oversee other agents
      assert supervisor.value == :supervisor
    end

    test "tool indicates agents providing specific functionality" do
      {:ok, tool} = AgentType.new(:tool)
      # In production, tool agents provide specific tool/service functionality
      assert tool.value == :tool
    end
  end
end
