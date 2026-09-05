defmodule ThalamusWeb.URLHelpersTest do
  use ExUnit.Case, async: true

  alias ThalamusWeb.URLHelpers

  setup do
    conn =
      Plug.Test.conn(:get, "/test")
      |> Map.put(:host, "sso.mycompany.org")
      |> Map.put(:port, 8443)
      |> Map.put(:scheme, :https)

    %{conn: conn}
  end

  describe "base_url/1" do
    test "extracts base URL from conn with custom port", %{conn: conn} do
      assert URLHelpers.base_url(conn) == "https://sso.mycompany.org:8443"
    end

    test "omits standard 443 port for https", %{conn: conn} do
      conn = %{conn | port: 443}
      assert URLHelpers.base_url(conn) == "https://sso.mycompany.org"
    end

    test "omits standard 80 port for http", %{conn: conn} do
      conn = %{conn | scheme: :http, port: 80}
      assert URLHelpers.base_url(conn) == "http://sso.mycompany.org"
    end

    test "respects x-forwarded headers from reverse proxy", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("x-forwarded-proto", "https")
        |> Plug.Conn.put_req_header("x-forwarded-host", "auth.enterprise.com")
        |> Plug.Conn.put_req_header("x-forwarded-port", "443")

      assert URLHelpers.base_url(conn) == "https://auth.enterprise.com"
    end

    test "falls back to Endpoint.url() when conn is nil" do
      assert is_binary(URLHelpers.base_url(nil))
    end
  end

  describe "resolve_social_redirect_uri/2" do
    test "generates dynamic callback URL using conn base URL", %{conn: conn} do
      assert URLHelpers.resolve_social_redirect_uri(conn, "google") ==
               "https://sso.mycompany.org:8443/auth/social/google/callback"

      assert URLHelpers.resolve_social_redirect_uri(conn, "github") ==
               "https://sso.mycompany.org:8443/auth/social/github/callback"

      assert URLHelpers.resolve_social_redirect_uri(conn, "apple") ==
               "https://sso.mycompany.org:8443/auth/social/apple/callback"
    end
  end

  describe "default fallbacks" do
    test "default_return_to returns root path without hardcoding external domain" do
      assert URLHelpers.default_return_to() == "/"
    end

    test "default_logout_url returns login path without hardcoding external domain" do
      assert URLHelpers.default_logout_url() == "/login"
    end

    test "home_url returns root path by default" do
      assert URLHelpers.home_url() == "/"
    end
  end
end
