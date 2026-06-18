defmodule Thalamus.Domain.ValueObjects.RedirectUriTest do
  use ExUnit.Case, async: false

  alias Thalamus.Domain.ValueObjects.RedirectUri

  describe "new/1" do
    test "creates valid HTTPS redirect URI" do
      assert {:ok, %RedirectUri{value: "https://app.example.com/callback"}} =
               RedirectUri.new("https://app.example.com/callback")

      assert {:ok, %RedirectUri{value: "https://example.com/auth/callback"}} =
               RedirectUri.new("https://example.com/auth/callback")
    end

    test "creates valid localhost HTTP redirect URI" do
      assert {:ok, %RedirectUri{value: "http://localhost:3000/callback"}} =
               RedirectUri.new("http://localhost:3000/callback")

      assert {:ok, %RedirectUri{value: "http://127.0.0.1:8080/auth"}} =
               RedirectUri.new("http://127.0.0.1:8080/auth")

      assert {:ok, %RedirectUri{value: "http://[::1]:3000/callback"}} =
               RedirectUri.new("http://[::1]:3000/callback")
    end

    test "creates valid private network HTTP redirect URI" do
      assert {:ok, _} = RedirectUri.new("http://192.168.1.100/callback")
      assert {:ok, _} = RedirectUri.new("http://10.0.0.1/callback")
      assert {:ok, _} = RedirectUri.new("http://172.16.0.1/callback")
      assert {:ok, _} = RedirectUri.new("http://172.31.255.255/callback")
    end

    test "returns error for empty string" do
      assert {:error, :invalid_redirect_uri} = RedirectUri.new("")
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_redirect_uri} = RedirectUri.new(nil)
      assert {:error, :invalid_redirect_uri} = RedirectUri.new(123)
      assert {:error, :invalid_redirect_uri} = RedirectUri.new([])
    end

    test "returns error for URI too short" do
      assert {:error, :redirect_uri_too_short} = RedirectUri.new("http:/")
      assert {:error, :redirect_uri_too_short} = RedirectUri.new("http:a")
      assert {:error, :redirect_uri_too_short} = RedirectUri.new("short")
    end

    test "returns error for URI too long" do
      long_uri = "https://example.com/" <> String.duplicate("a", 2048)
      assert {:error, :redirect_uri_too_long} = RedirectUri.new(long_uri)
    end

    test "returns error for invalid URI format" do
      assert {:error, :invalid_redirect_uri_format} = RedirectUri.new("invalid-uri")
      assert {:error, :invalid_redirect_uri_format} = RedirectUri.new("not a uri")
      assert {:error, :invalid_redirect_uri_format} = RedirectUri.new("://missing-scheme")
      assert {:error, :invalid_redirect_uri_format} = RedirectUri.new("no-scheme-host")
    end

    test "returns error for invalid scheme" do
      assert {:error, :invalid_redirect_uri_scheme} =
               RedirectUri.new("ftp://example.com/callback")

      assert {:error, :invalid_redirect_uri_scheme} = RedirectUri.new("file:///etc/passwd")
      assert {:error, :invalid_redirect_uri_scheme} = RedirectUri.new("data://text/html,test")
    end

    test "returns error for URI with fragment" do
      assert {:error, :redirect_uri_has_fragment} =
               RedirectUri.new("https://example.com/callback#fragment")

      assert {:error, :redirect_uri_has_fragment} =
               RedirectUri.new("http://localhost:3000/auth#token")
    end

    test "accepts URIs at minimum valid length" do
      # 8 characters: minimum valid URI
      assert {:ok, _} = RedirectUri.new("https://a")
      assert {:ok, _} = RedirectUri.new("http://ab")
    end

    test "accepts URIs at maximum valid length" do
      # 2048 characters is the max
      long_path = String.duplicate("a", 2048 - String.length("https://example.com/"))
      long_uri = "https://example.com/" <> long_path
      assert {:ok, _} = RedirectUri.new(long_uri)
    end
  end

  describe "to_string/1" do
    test "converts RedirectUri to string" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.to_string(uri) == "https://app.example.com/callback"
    end
  end

  describe "from_string/1" do
    test "creates RedirectUri from valid string" do
      assert {:ok, %RedirectUri{value: "https://example.com/callback"}} =
               RedirectUri.from_string("https://example.com/callback")
    end

    test "returns error for invalid string" do
      assert {:error, :redirect_uri_too_short} = RedirectUri.from_string("invalid")
      assert {:error, :invalid_redirect_uri_format} = RedirectUri.from_string("notavaliduri")
    end
  end

  describe "secure?/1" do
    test "returns true for HTTPS URIs" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.secure?(uri) == true
    end

    test "returns true for localhost HTTP URIs" do
      {:ok, uri} = RedirectUri.new("http://localhost:3000/callback")
      assert RedirectUri.secure?(uri) == true

      {:ok, uri} = RedirectUri.new("http://127.0.0.1:8080/auth")
      assert RedirectUri.secure?(uri) == true

      {:ok, uri} = RedirectUri.new("http://[::1]:3000/callback")
      assert RedirectUri.secure?(uri) == true
    end

    test "returns true for private network HTTP URIs" do
      {:ok, uri} = RedirectUri.new("http://192.168.1.100/callback")
      assert RedirectUri.secure?(uri) == true

      {:ok, uri} = RedirectUri.new("http://10.0.0.1/callback")
      assert RedirectUri.secure?(uri) == true

      {:ok, uri} = RedirectUri.new("http://172.16.0.1/callback")
      assert RedirectUri.secure?(uri) == true

      {:ok, uri} = RedirectUri.new("http://172.31.255.255/callback")
      assert RedirectUri.secure?(uri) == true
    end

    test "returns false for public HTTP URIs" do
      {:ok, uri} = RedirectUri.new("http://example.com/callback")
      assert RedirectUri.secure?(uri) == false

      {:ok, uri} = RedirectUri.new("http://app.example.com/auth")
      assert RedirectUri.secure?(uri) == false
    end

    test "returns false for private network outside 172.16-31 range" do
      {:ok, uri} = RedirectUri.new("http://172.15.0.1/callback")
      assert RedirectUri.secure?(uri) == false

      {:ok, uri} = RedirectUri.new("http://172.32.0.1/callback")
      assert RedirectUri.secure?(uri) == false
    end

    test "returns true for all 127.x.x.x addresses" do
      {:ok, uri} = RedirectUri.new("http://127.100.200.50/callback")
      assert RedirectUri.secure?(uri) == true
    end
  end

  describe "localhost?/1" do
    test "returns true for localhost hostname" do
      {:ok, uri} = RedirectUri.new("http://localhost:3000/callback")
      assert RedirectUri.localhost?(uri) == true

      {:ok, uri} = RedirectUri.new("https://localhost/callback")
      assert RedirectUri.localhost?(uri) == true
    end

    test "returns true for 127.x.x.x IP addresses" do
      {:ok, uri} = RedirectUri.new("http://127.0.0.1:8080/callback")
      assert RedirectUri.localhost?(uri) == true

      {:ok, uri} = RedirectUri.new("http://127.1.1.1/callback")
      assert RedirectUri.localhost?(uri) == true

      {:ok, uri} = RedirectUri.new("http://127.255.255.255/callback")
      assert RedirectUri.localhost?(uri) == true
    end

    test "returns true for ::1 IPv6 loopback" do
      {:ok, uri} = RedirectUri.new("http://[::1]:3000/callback")
      assert RedirectUri.localhost?(uri) == true
    end

    test "returns true for 192.168.x.x private network" do
      {:ok, uri} = RedirectUri.new("http://192.168.1.100/callback")
      assert RedirectUri.localhost?(uri) == true

      {:ok, uri} = RedirectUri.new("http://192.168.0.1/callback")
      assert RedirectUri.localhost?(uri) == true
    end

    test "returns true for 10.x.x.x private network" do
      {:ok, uri} = RedirectUri.new("http://10.0.0.1/callback")
      assert RedirectUri.localhost?(uri) == true

      {:ok, uri} = RedirectUri.new("http://10.255.255.255/callback")
      assert RedirectUri.localhost?(uri) == true
    end

    test "returns true for 172.16-31.x.x private network" do
      {:ok, uri} = RedirectUri.new("http://172.16.0.1/callback")
      assert RedirectUri.localhost?(uri) == true

      {:ok, uri} = RedirectUri.new("http://172.31.255.255/callback")
      assert RedirectUri.localhost?(uri) == true
    end

    test "returns false for public IP addresses" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.localhost?(uri) == false

      {:ok, uri} = RedirectUri.new("http://8.8.8.8/callback")
      assert RedirectUri.localhost?(uri) == false
    end

    test "returns false for 172.x.x.x outside 16-31 range" do
      {:ok, uri} = RedirectUri.new("http://172.15.0.1/callback")
      assert RedirectUri.localhost?(uri) == false

      {:ok, uri} = RedirectUri.new("http://172.32.0.1/callback")
      assert RedirectUri.localhost?(uri) == false
    end

    test "returns false for malformed 172.x addresses" do
      {:ok, uri} = RedirectUri.new("http://172.abc.0.1/callback")
      assert RedirectUri.localhost?(uri) == false

      {:ok, uri} = RedirectUri.new("http://172.16abc.0.1/callback")
      assert RedirectUri.localhost?(uri) == false
    end

    test "handles edge cases for 172.x validation" do
      # Short 172.x addresses that don't reach minimum length
      {:ok, uri} = RedirectUri.new("http://172.1.2.3/callback")
      assert RedirectUri.localhost?(uri) == false

      # 172.0.x.x is not in the 16-31 range
      {:ok, uri} = RedirectUri.new("http://172.0.0.1/callback")
      assert RedirectUri.localhost?(uri) == false
    end
  end

  describe "host/1" do
    test "extracts host from redirect URI" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.host(uri) == "app.example.com"

      {:ok, uri} = RedirectUri.new("http://localhost:3000/auth")
      assert RedirectUri.host(uri) == "localhost"
    end
  end

  describe "scheme/1" do
    test "extracts scheme from redirect URI" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.scheme(uri) == "https"

      {:ok, uri} = RedirectUri.new("http://localhost:3000/auth")
      assert RedirectUri.scheme(uri) == "http"
    end
  end

  describe "path/1" do
    test "extracts path from redirect URI" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.path(uri) == "/callback"

      {:ok, uri} = RedirectUri.new("http://localhost:3000/auth/callback")
      assert RedirectUri.path(uri) == "/auth/callback"
    end
  end

  describe "allowed?/2" do
    test "returns true when URI is in allowed list" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      allowed = ["https://app.example.com/callback", "https://app.example.com/auth"]
      assert RedirectUri.allowed?(uri, allowed) == true
    end

    test "returns false when URI is not in allowed list" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      allowed = ["https://other.com/callback"]
      assert RedirectUri.allowed?(uri, allowed) == false
    end

    test "returns false for empty allowed list" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert RedirectUri.allowed?(uri, []) == false
    end
  end

  describe "String.Chars protocol" do
    test "converts RedirectUri to string" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert to_string(uri) == "https://app.example.com/callback"
    end
  end

  describe "Jason.Encoder protocol" do
    test "encodes RedirectUri to JSON" do
      {:ok, uri} = RedirectUri.new("https://app.example.com/callback")
      assert {:ok, json} = Jason.encode(uri)
      assert json == "\"https://app.example.com/callback\""
    end
  end
end
