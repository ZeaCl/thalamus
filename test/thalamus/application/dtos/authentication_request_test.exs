defmodule Thalamus.Application.DTOs.AuthenticationRequestTest do
  use ExUnit.Case, async: false

  alias Thalamus.Application.DTOs.AuthenticationRequest

  describe "new/1" do
    test "creates a valid authentication request with required fields" do
      params = %{
        email: "user@example.com",
        password: "SecureP@ssw0rd123"
      }

      assert {:ok, request} = AuthenticationRequest.new(params)
      assert request.email == "user@example.com"
      assert request.password == "SecureP@ssw0rd123"
      assert request.mfa_code == nil
      assert request.context == %{}
    end

    test "creates request with MFA code" do
      params = %{
        email: "user@example.com",
        password: "SecureP@ssw0rd123",
        mfa_code: "123456"
      }

      assert {:ok, request} = AuthenticationRequest.new(params)
      assert request.mfa_code == "123456"
    end

    test "creates request with context" do
      context = %{ip_address: "192.168.1.1", user_agent: "Mozilla/5.0"}

      params = %{
        email: "user@example.com",
        password: "SecureP@ssw0rd123",
        context: context
      }

      assert {:ok, request} = AuthenticationRequest.new(params)
      assert request.context == context
    end

    test "creates request with all optional fields" do
      context = %{ip_address: "192.168.1.1"}

      params = %{
        email: "user@example.com",
        password: "SecureP@ssw0rd123",
        mfa_code: "654321",
        context: context
      }

      assert {:ok, request} = AuthenticationRequest.new(params)
      assert request.email == "user@example.com"
      assert request.password == "SecureP@ssw0rd123"
      assert request.mfa_code == "654321"
      assert request.context == context
    end

    test "returns error when email is empty" do
      params = %{
        email: "",
        password: "SecureP@ssw0rd123"
      }

      assert {:error, :email_required} = AuthenticationRequest.new(params)
    end

    test "returns error when password is empty" do
      params = %{
        email: "user@example.com",
        password: ""
      }

      assert {:error, :password_required} = AuthenticationRequest.new(params)
    end

    test "returns error when email is missing" do
      params = %{password: "SecureP@ssw0rd123"}

      assert {:error, :invalid_request} = AuthenticationRequest.new(params)
    end

    test "returns error when password is missing" do
      params = %{email: "user@example.com"}

      assert {:error, :invalid_request} = AuthenticationRequest.new(params)
    end

    test "returns error with invalid params (not a map)" do
      assert {:error, :invalid_request} = AuthenticationRequest.new("invalid")
    end

    test "returns error with empty map" do
      assert {:error, :invalid_request} = AuthenticationRequest.new(%{})
    end

    test "returns error with nil" do
      assert {:error, :invalid_request} = AuthenticationRequest.new(nil)
    end
  end
end
