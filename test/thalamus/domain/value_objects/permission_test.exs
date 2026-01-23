defmodule Thalamus.Domain.ValueObjects.PermissionTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.Permission

  describe "new/1 - valid scopes" do
    test "creates Permission with valid OIDC scope" do
      assert {:ok, %Permission{value: "openid"}} = Permission.new("openid")
    end

    test "creates Permission with namespaced scope" do
      assert {:ok, %Permission{value: "api:read"}} = Permission.new("api:read")
    end

    test "creates Permission with 2-level MCP scope" do
      assert {:ok, %Permission{value: "mcp:gmail:read"}} = Permission.new("mcp:gmail:read")
    end

    test "creates Permission with 3-level MCP scope" do
      assert {:ok, %Permission{value: "mcp:slack:channels:list"}} =
               Permission.new("mcp:slack:channels:list")
    end

    test "creates Permission with underscores and hyphens" do
      assert {:ok, %Permission{value: "api_v2:read-only"}} = Permission.new("api_v2:read-only")
    end

    test "creates Permission with max length (128 chars)" do
      # 128 characters exactly
      scope = String.duplicate("a", 128)
      assert {:ok, %Permission{value: ^scope}} = Permission.new(scope)
    end
  end

  describe "new/1 - invalid scopes" do
    test "rejects scope with uppercase letters" do
      assert {:error, :invalid_scope_format} = Permission.new("CAPS")
    end

    test "rejects scope starting with number" do
      assert {:error, :invalid_scope_format} = Permission.new("123start")
    end

    test "rejects scope with too many colons (>4 levels)" do
      assert {:error, :invalid_scope_format} =
               Permission.new("too:many:colons:here:invalid")
    end

    test "rejects scope with special characters" do
      assert {:error, :invalid_scope_format} = Permission.new("invalid!")
      assert {:error, :invalid_scope_format} = Permission.new("invalid scope")
      assert {:error, :invalid_scope_format} = Permission.new("invalid@scope")
    end

    test "rejects empty string" do
      assert {:error, :invalid_scope_format} = Permission.new("")
    end

    test "rejects scope longer than 128 characters" do
      # 129 characters
      scope = String.duplicate("a", 129)
      assert {:error, :scope_too_long} = Permission.new(scope)
    end

    test "rejects non-string input" do
      assert {:error, :invalid_scope_format} = Permission.new(nil)
      assert {:error, :invalid_scope_format} = Permission.new(123)
      assert {:error, :invalid_scope_format} = Permission.new(:atom)
    end

    test "rejects scope with trailing colon" do
      assert {:error, :invalid_scope_format} = Permission.new("api:")
    end

    test "rejects scope with leading colon" do
      assert {:error, :invalid_scope_format} = Permission.new(":read")
    end

    test "rejects scope with double colon" do
      assert {:error, :invalid_scope_format} = Permission.new("api::read")
    end
  end

  describe "valid_format?/1" do
    test "returns true for valid scopes" do
      assert Permission.valid_format?("openid")
      assert Permission.valid_format?("api:read")
      assert Permission.valid_format?("mcp:gmail:read")
      assert Permission.valid_format?("mcp:slack:channels:list")
    end

    test "returns false for invalid scopes" do
      refute Permission.valid_format?("CAPS")
      refute Permission.valid_format?("123start")
      refute Permission.valid_format?("too:many:colons:here:invalid")
      refute Permission.valid_format?("invalid!")
      refute Permission.valid_format?("")
      refute Permission.valid_format?(nil)
    end
  end

  describe "to_string/1" do
    test "converts Permission to string" do
      {:ok, permission} = Permission.new("api:read")
      assert Permission.to_string(permission) == "api:read"
    end
  end

  describe "String.Chars protocol" do
    test "converts Permission to string via protocol" do
      {:ok, permission} = Permission.new("openid")
      assert Kernel.to_string(permission) == "openid"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes Permission as JSON string" do
      {:ok, permission} = Permission.new("api:write")
      assert Jason.encode!(permission) == ~s("api:write")
    end
  end
end
