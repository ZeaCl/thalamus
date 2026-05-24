defmodule Thalamus.Application.DTOs.TokenResponseTest do
  use ExUnit.Case, async: true

  alias Thalamus.Application.DTOs.TokenResponse

  describe "success/5" do
    test "creates a token response with access token and expires_in" do
      response = TokenResponse.success("access_token_123", 3600)

      assert response.access_token == "access_token_123"
      assert response.token_type == "Bearer"
      assert response.expires_in == 3600
      assert response.refresh_token == nil
      assert response.scope == nil
      assert response.id_token == nil
    end

    test "creates a token response with refresh token" do
      response = TokenResponse.success("access_token_123", 3600, "refresh_token_456")

      assert response.access_token == "access_token_123"
      assert response.refresh_token == "refresh_token_456"
    end

    test "creates a token response with scope" do
      response = TokenResponse.success("access_token_123", 3600, nil, "openid profile")

      assert response.access_token == "access_token_123"
      assert response.scope == "openid profile"
    end

    test "creates a token response with id_token" do
      response =
        TokenResponse.success(
          "access_token_123",
          3600,
          nil,
          nil,
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        )

      assert response.access_token == "access_token_123"
      assert response.id_token == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    end

    test "creates a token response with all optional fields" do
      response =
        TokenResponse.success(
          "access_token_123",
          3600,
          "refresh_token_456",
          "openid profile email",
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        )

      assert response.access_token == "access_token_123"
      assert response.token_type == "Bearer"
      assert response.expires_in == 3600
      assert response.refresh_token == "refresh_token_456"
      assert response.scope == "openid profile email"
      assert response.id_token == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    end
  end

  describe "to_map/1" do
    test "converts response with only required fields to map" do
      response = TokenResponse.success("access_token_123", 3600)
      map = TokenResponse.to_map(response)

      assert map == %{
               access_token: "access_token_123",
               token_type: "Bearer",
               expires_in: 3600
             }
    end

    test "converts response with refresh_token to map" do
      response = TokenResponse.success("access_token_123", 3600, "refresh_token_456")
      map = TokenResponse.to_map(response)

      assert map == %{
               access_token: "access_token_123",
               token_type: "Bearer",
               expires_in: 3600,
               refresh_token: "refresh_token_456"
             }
    end

    test "converts response with scope to map" do
      response = TokenResponse.success("access_token_123", 3600, nil, "openid profile")
      map = TokenResponse.to_map(response)

      assert map == %{
               access_token: "access_token_123",
               token_type: "Bearer",
               expires_in: 3600,
               scope: "openid profile"
             }
    end

    test "converts response with id_token to map" do
      response = TokenResponse.success("access_token_123", 3600, nil, nil, "id_token_xyz")
      map = TokenResponse.to_map(response)

      assert map == %{
               access_token: "access_token_123",
               token_type: "Bearer",
               expires_in: 3600,
               id_token: "id_token_xyz"
             }
    end

    test "converts response with all fields to map" do
      response =
        TokenResponse.success(
          "access_token_123",
          3600,
          "refresh_token_456",
          "openid profile",
          "id_token_xyz"
        )

      map = TokenResponse.to_map(response)

      assert map == %{
               access_token: "access_token_123",
               token_type: "Bearer",
               expires_in: 3600,
               refresh_token: "refresh_token_456",
               scope: "openid profile",
               id_token: "id_token_xyz"
             }
    end

    test "excludes nil values from map" do
      response =
        TokenResponse.success("access_token_123", 7200, "refresh_token_456", nil, nil)

      map = TokenResponse.to_map(response)

      refute Map.has_key?(map, :scope)
      refute Map.has_key?(map, :id_token)
      assert Map.has_key?(map, :access_token)
      assert Map.has_key?(map, :refresh_token)
    end
  end
end
