defmodule Thalamus.Infrastructure.Adapters.SocialAuth.GitHubAdapterTest do
  use ExUnit.Case, async: true

  alias Thalamus.Infrastructure.Adapters.SocialAuth.GitHubAdapter

  defmodule MockHttpClient do
    def post("https://github.com/login/oauth/access_token",
          form: %{"code" => "valid_code"},
          headers: _
        ) do
      {:ok, %{status: 200, body: %{"access_token" => "gh_token_123"}}}
    end

    def post("https://github.com/login/oauth/access_token",
          form: %{"code" => "invalid_code"},
          headers: _
        ) do
      {:ok, %{status: 400, body: %{"error" => "bad_verification_code"}}}
    end

    def get("https://api.github.com/user", headers: _) do
      {:ok,
       %{
         status: 200,
         body: %{
           "id" => 54_321,
           "login" => "octocat",
           "name" => "The Octocat",
           "avatar_url" => "https://avatars.githubusercontent.com/u/54321?v=4",
           "email" => nil
         }
       }}
    end

    def get("https://api.github.com/user/emails", headers: _) do
      {:ok,
       %{
         status: 200,
         body: [
           %{"email" => "secondary@example.com", "primary" => false, "verified" => true},
           %{"email" => "primary@example.com", "primary" => true, "verified" => true}
         ]
       }}
    end
  end

  describe "get_authorization_url/2" do
    test "generates authorization URL with GitHub parameters" do
      opts = [
        client_id: "test_github_client_id",
        redirect_uri: "https://auth.zea.cl/auth/social/github/callback"
      ]

      assert {:ok, url} = GitHubAdapter.get_authorization_url("state_gh_999", opts)
      uri = URI.parse(url)

      assert uri.host == "github.com"
      assert uri.path == "/login/oauth/authorize"

      params = URI.decode_query(uri.query)
      assert params["client_id"] == "test_github_client_id"
      assert params["redirect_uri"] == "https://auth.zea.cl/auth/social/github/callback"
      assert params["scope"] == "read:user user:email"
      assert params["state"] == "state_gh_999"
    end

    test "returns error if client_id is missing" do
      assert {:error, :missing_github_client_id} =
               GitHubAdapter.get_authorization_url("state", client_id: nil)
    end
  end

  describe "exchange_code/2" do
    test "successfully exchanges code, fetches profile and verified primary email" do
      opts = [
        client_id: "test_id",
        client_secret: "test_secret",
        redirect_uri: "https://auth.zea.cl/auth/social/github/callback",
        http_client: MockHttpClient
      ]

      assert {:ok, profile} = GitHubAdapter.exchange_code("valid_code", opts)
      assert profile.provider == "github"
      assert profile.provider_uid == "54321"
      assert profile.email == "primary@example.com"
      assert profile.email_verified == true
      assert profile.name == "The Octocat"
      assert profile.avatar_url == "https://avatars.githubusercontent.com/u/54321?v=4"
    end

    test "handles failed token exchange" do
      opts = [
        client_id: "test_id",
        client_secret: "test_secret",
        http_client: MockHttpClient
      ]

      assert {:error, :token_exchange_failed} = GitHubAdapter.exchange_code("invalid_code", opts)
    end

    test "prefers verified email when primary email is unverified" do
      defmodule MockUnverifiedPrimaryHttpClient do
        def post("https://github.com/login/oauth/access_token", form: _, headers: _) do
          {:ok, %{status: 200, body: %{"access_token" => "gh_token_456"}}}
        end

        def get("https://api.github.com/user", headers: _) do
          {:ok, %{status: 200, body: %{"id" => 999, "login" => "testdev", "name" => "Dev"}}}
        end

        def get("https://api.github.com/user/emails", headers: _) do
          {:ok,
           %{
             status: 200,
             body: [
               %{
                 "email" => "unverified_primary@example.com",
                 "primary" => true,
                 "verified" => false
               },
               %{
                 "email" => "verified_secondary@example.com",
                 "primary" => false,
                 "verified" => true
               }
             ]
           }}
        end
      end

      opts = [
        client_id: "test_id",
        client_secret: "test_secret",
        http_client: MockUnverifiedPrimaryHttpClient
      ]

      assert {:ok, profile} = GitHubAdapter.exchange_code("valid_code", opts)
      assert profile.email == "verified_secondary@example.com"
      assert profile.email_verified == true
    end
  end
end
