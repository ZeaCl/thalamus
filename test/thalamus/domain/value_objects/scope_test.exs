defmodule Thalamus.Domain.ValueObjects.ScopeTest do
  use ExUnit.Case, async: true

  alias Thalamus.Domain.ValueObjects.Scope

  describe "new/1" do
    test "creates valid standard scope" do
      assert {:ok, %Scope{value: "openid"}} = Scope.new("openid")
      assert {:ok, %Scope{value: "profile"}} = Scope.new("profile")
      assert {:ok, %Scope{value: "email"}} = Scope.new("email")
    end

    test "creates valid API scope" do
      assert {:ok, %Scope{value: "api:read"}} = Scope.new("api:read")
      assert {:ok, %Scope{value: "api:write"}} = Scope.new("api:write")
    end

    test "normalizes scope to lowercase" do
      assert {:ok, %Scope{value: "openid"}} = Scope.new("OPENID")
      assert {:ok, %Scope{value: "api:read"}} = Scope.new("API:READ")
    end

    test "trims whitespace" do
      assert {:ok, %Scope{value: "openid"}} = Scope.new("  openid  ")
    end

    test "returns error for empty string" do
      assert {:error, :invalid_scope} = Scope.new("")
    end

    test "returns error for unknown scope" do
      assert {:error, :unknown_scope} = Scope.new("invalid_scope")
    end

    test "returns error for invalid format with special chars" do
      assert {:error, :invalid_scope_format} = Scope.new("scope!")
    end

    test "returns error for scope too long" do
      long_scope = String.duplicate("a", 101)
      assert {:error, :scope_too_long} = Scope.new(long_scope)
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_scope} = Scope.new(nil)
      assert {:error, :invalid_scope} = Scope.new(123)
    end
  end

  describe "from_string/1" do
    test "creates multiple scopes from space-separated string" do
      assert {:ok, scopes} = Scope.from_string("openid profile email")
      assert length(scopes) == 3
      assert [%Scope{value: "openid"}, %Scope{value: "profile"}, %Scope{value: "email"}] = scopes
    end

    test "handles single scope" do
      assert {:ok, [%Scope{value: "openid"}]} = Scope.from_string("openid")
    end

    test "trims extra spaces" do
      assert {:ok, scopes} = Scope.from_string("  openid   profile  ")
      assert length(scopes) == 2
    end

    test "returns error for invalid scope in string" do
      assert {:error, :unknown_scope} = Scope.from_string("openid invalid_scope")
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_input} = Scope.from_string(nil)
    end
  end

  describe "to_string/1" do
    test "converts single scope to string" do
      {:ok, scope} = Scope.new("openid")
      assert Scope.to_string(scope) == "openid"
    end

    test "converts list of scopes to space-separated string" do
      {:ok, scope1} = Scope.new("openid")
      {:ok, scope2} = Scope.new("profile")
      assert Scope.to_string([scope1, scope2]) == "openid profile"
    end

    test "handles empty list" do
      assert Scope.to_string([]) == ""
    end
  end

  describe "standard?/1" do
    test "returns true for standard OpenID Connect scopes" do
      {:ok, scope} = Scope.new("openid")
      assert Scope.standard?(scope) == true

      {:ok, scope} = Scope.new("profile")
      assert Scope.standard?(scope) == true
    end

    test "returns false for API scopes" do
      {:ok, scope} = Scope.new("api:read")
      assert Scope.standard?(scope) == false
    end
  end

  describe "zea_scope?/1" do
    test "returns true for API platform scopes" do
      {:ok, scope} = Scope.new("api:read")
      assert Scope.zea_scope?(scope) == true

      {:ok, scope} = Scope.new("webhooks:manage")
      assert Scope.zea_scope?(scope) == true
    end

    test "returns false for standard scopes" do
      {:ok, scope} = Scope.new("openid")
      assert Scope.zea_scope?(scope) == false
    end
  end

  describe "requires_special_permission?/1" do
    test "returns true for admin scopes" do
      {:ok, scope} = Scope.new("api:admin")
      assert Scope.requires_special_permission?(scope) == true
    end

    test "returns true for billing write" do
      {:ok, scope} = Scope.new("billing:write")
      assert Scope.requires_special_permission?(scope) == true
    end

    test "returns true for offline access" do
      {:ok, scope} = Scope.new("offline_access")
      assert Scope.requires_special_permission?(scope) == true
    end

    test "returns false for read scopes" do
      {:ok, scope} = Scope.new("api:read")
      assert Scope.requires_special_permission?(scope) == false
    end
  end

  describe "resource_type/1" do
    test "extracts resource from namespaced scope" do
      {:ok, scope} = Scope.new("api:read")
      assert Scope.resource_type(scope) == "api"

      {:ok, scope} = Scope.new("webhooks:manage")
      assert Scope.resource_type(scope) == "webhooks"
    end

    test "returns identity for standard scopes" do
      {:ok, scope} = Scope.new("openid")
      assert Scope.resource_type(scope) == "identity"

      {:ok, scope} = Scope.new("profile")
      assert Scope.resource_type(scope) == "identity"
    end
  end

  describe "action/1" do
    test "extracts action from namespaced scope" do
      {:ok, scope} = Scope.new("api:read")
      assert Scope.action(scope) == "read"

      {:ok, scope} = Scope.new("billing:write")
      assert Scope.action(scope) == "write"
    end

    test "returns access for standard scopes" do
      {:ok, scope} = Scope.new("openid")
      assert Scope.action(scope) == "access"

      {:ok, scope} = Scope.new("profile")
      assert Scope.action(scope) == "access"
    end
  end

  describe "valid_scopes/0" do
    test "returns list of all valid scopes" do
      scopes = Scope.valid_scopes()
      assert is_list(scopes)
      assert "openid" in scopes
      assert "profile" in scopes
      assert "api:read" in scopes
      assert "api:write" in scopes
    end
  end

  describe "String.Chars protocol" do
    test "converts scope to string" do
      {:ok, scope} = Scope.new("openid")
      assert to_string(scope) == "openid"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes scope to JSON" do
      {:ok, scope} = Scope.new("openid")
      assert {:ok, json} = Jason.encode(scope)
      assert json == "\"openid\""
    end
  end
end
