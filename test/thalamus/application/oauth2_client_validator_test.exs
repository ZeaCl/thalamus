defmodule Thalamus.OAuth2ClientValidatorTest do
  use ExUnit.Case, async: true

  alias Thalamus.OAuth2ClientValidator
  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{ClientId, OrganizationId, GrantType, RedirectUri, Scope}

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp build_client(attrs \\ []) do
    {:ok, client_id} = ClientId.generate()
    {:ok, org_id} = OrganizationId.generate()
    {:ok, auth_code} = GrantType.new(:authorization_code)
    {:ok, openid} = Scope.new("openid")
    {:ok, redirect} = RedirectUri.new("http://app.zea.localhost/callback")

    defaults = %{
      id: client_id,
      organization_id: org_id,
      name: "Test Client",
      description: nil,
      client_type: :public,
      client_secret: nil,
      grant_types: [auth_code],
      redirect_uris: [redirect],
      allowed_scopes: [openid],
      is_active: true,
      trusted: false,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    attrs_map = Map.new(attrs)
    struct(OAuth2Client, Map.merge(defaults, attrs_map))
  end

  defp setup_cors(origins) do
    Application.put_env(:thalamus, ThalamusWeb.Plugs.CORS, origins: origins)

    on_exit(fn ->
      Application.delete_env(:thalamus, ThalamusWeb.Plugs.CORS)
    end)
  end

  defp setup_csp(policy) do
    Application.put_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders, csp_policy: policy)

    on_exit(fn ->
      Application.delete_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders)
    end)
  end

  # ── Tests: client_active ─────────────────────────────────────────────────

  describe "client_active" do
    test "passes when client is active" do
      client = build_client(is_active: true)
      checks = OAuth2ClientValidator.run(client)
      assert %{check: "client_active", status: "pass"} in checks
    end

    test "fails when client is inactive" do
      client = build_client(is_active: false)
      checks = OAuth2ClientValidator.run(client)
      check = Enum.find(checks, &(&1.check == "client_active"))
      assert check.status == "fail"
      assert check.detail =~ "deactivated"
    end
  end

  # ── Tests: client_type_coherence ─────────────────────────────────────────

  describe "client_type_coherence / SPA" do
    test "passes for well-configured SPA" do
      client = build_client(client_type: :public)
      checks = OAuth2ClientValidator.run(client)
      assert %{check: "grant_types", status: "pass"} in checks
      assert %{check: "redirect_uris_present", status: "pass"} in checks
    end

    test "fails when SPA lacks authorization_code grant" do
      {:ok, cc} = GrantType.new(:client_credentials)
      client = build_client(client_type: :public, grant_types: [cc])
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "grant_types"))
      assert check.status == "fail"
      assert check.detail =~ "authorization_code"
    end

    test "fails when SPA has no redirect URIs" do
      client = build_client(client_type: :public, redirect_uris: [])
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "redirect_uris_present"))
      assert check.status == "fail"
      assert check.detail =~ "redirect URI"
    end
  end

  describe "client_type_coherence / Backend" do
    test "passes for well-configured confidential client" do
      {:ok, cc} = GrantType.new(:client_credentials)
      client = build_client(client_type: :confidential, grant_types: [cc], redirect_uris: [])
      checks = OAuth2ClientValidator.run(client)
      assert %{check: "grant_types", status: "pass"} in checks
    end

    test "warns when backend lacks client_credentials" do
      {:ok, auth_code} = GrantType.new(:authorization_code)

      client =
        build_client(client_type: :confidential, grant_types: [auth_code], redirect_uris: [])

      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "grant_types"))
      assert check.status == "warn"
      assert check.detail =~ "client_credentials"
    end
  end

  # ── Tests: scopes ────────────────────────────────────────────────────────

  describe "scopes" do
    test "passes when openid is in allowed_scopes" do
      client = build_client()
      checks = OAuth2ClientValidator.run(client)
      assert %{check: "has_openid_scope", status: "pass"} in checks
    end

    test "fails when openid is missing" do
      {:ok, profile} = Scope.new("profile")
      client = build_client(allowed_scopes: [profile])
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "has_openid_scope"))
      assert check.status == "fail"
      assert check.detail =~ "openid"
    end
  end

  # ── Tests: redirect URI format ───────────────────────────────────────────

  describe "redirect_uri_format" do
    test "passes for valid http/https URIs" do
      {:ok, uri1} = RedirectUri.new("http://app.zea.localhost/callback")
      {:ok, uri2} = RedirectUri.new("https://app.zea.cl/callback")
      client = build_client(redirect_uris: [uri1, uri2])

      checks = OAuth2ClientValidator.run(client)
      refute Enum.any?(checks, &(&1.check == "redirect_uri_format"))
    end
  end

  # ── Tests: CORS ──────────────────────────────────────────────────────────

  describe "cors_origins" do
    test "passes when origin is in CORS_ORIGINS" do
      setup_cors(["http://app.zea.localhost"])
      client = build_client()
      checks = OAuth2ClientValidator.run(client)
      assert %{check: "cors_origins", status: "pass"} in checks
    end

    test "fails when origin is missing from CORS_ORIGINS" do
      setup_cors(["http://other.localhost"])
      client = build_client()
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "cors_origins"))
      assert check.status == "fail"
      assert check.detail =~ "docker-compose.yml"
    end

    test "warns when CORS_ORIGINS is not configured" do
      Application.put_env(:thalamus, ThalamusWeb.Plugs.CORS, [])

      on_exit(fn ->
        Application.delete_env(:thalamus, ThalamusWeb.Plugs.CORS)
      end)

      client = build_client()
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "cors_origins"))
      assert check.status == "warn"
      assert check.detail =~ "not configured"
    end

    test "deduplicates same origin from multiple redirect URIs" do
      setup_cors(["http://app.zea.localhost"])
      {:ok, uri1} = RedirectUri.new("http://app.zea.localhost/callback")
      {:ok, uri2} = RedirectUri.new("http://app.zea.localhost/other")
      client = build_client(redirect_uris: [uri1, uri2])

      checks = OAuth2ClientValidator.run(client)
      cors_checks = Enum.filter(checks, &(&1.check == "cors_origins"))
      assert length(cors_checks) == 1
    end
  end

  # ── Tests: CSP ───────────────────────────────────────────────────────────

  describe "csp_form_action" do
    test "passes when host is covered by wildcard" do
      setup_csp(
        "default-src 'self'; form-action 'self' http://*.zea.localhost:* https://*.zea.cl"
      )

      client = build_client()
      checks = OAuth2ClientValidator.run(client)

      assert %{check: "csp_form_action", status: "pass"} in checks
    end

    test "passes when host is covered by exact entry" do
      setup_csp("default-src 'self'; form-action 'self' http://app.zea.localhost:*")
      client = build_client()
      checks = OAuth2ClientValidator.run(client)

      assert %{check: "csp_form_action", status: "pass"} in checks
    end

    test "warns when host is not covered" do
      setup_csp("default-src 'self'; form-action 'self' http://other.localhost:*")
      client = build_client()
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "csp_form_action"))
      assert check.status == "warn"
      assert check.detail =~ "config/config.exs"
    end

    test "fails when CSP is not configured" do
      Application.put_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders, [])

      on_exit(fn ->
        Application.delete_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders)
      end)

      client = build_client()
      checks = OAuth2ClientValidator.run(client)

      check = Enum.find(checks, &(&1.check == "csp_policy"))
      assert check.status == "fail"
      assert check.detail =~ "not configured"
    end

    test "covers subdomain via *.domain wildcard for prod" do
      setup_csp("default-src 'self'; form-action 'self' https://*.zea.cl")
      {:ok, uri} = RedirectUri.new("https://sudlich.zea.cl/callback")
      client = build_client(redirect_uris: [uri])
      checks = OAuth2ClientValidator.run(client)

      assert %{check: "csp_form_action", status: "pass"} in checks
    end

    test "deduplicates same host from multiple redirect URIs" do
      setup_csp("default-src 'self'; form-action 'self' http://*.zea.localhost:*")
      {:ok, uri1} = RedirectUri.new("http://app.zea.localhost/callback")
      {:ok, uri2} = RedirectUri.new("http://app.zea.localhost/other")
      client = build_client(redirect_uris: [uri1, uri2])

      checks = OAuth2ClientValidator.run(client)
      csp_checks = Enum.filter(checks, &(&1.check == "csp_form_action"))
      assert length(csp_checks) == 1
    end
  end

  # ── Tests: overall_status ────────────────────────────────────────────────

  describe "overall_status/1" do
    test "returns 'valid' when all checks pass" do
      checks = [
        %{check: "a", status: "pass"},
        %{check: "b", status: "pass"}
      ]

      assert OAuth2ClientValidator.overall_status(checks) == "valid"
    end

    test "returns 'invalid' when any check fails" do
      checks = [
        %{check: "a", status: "pass"},
        %{check: "b", status: "fail", detail: "broken"}
      ]

      assert OAuth2ClientValidator.overall_status(checks) == "invalid"
    end

    test "returns 'warning' when only warns exist" do
      checks = [
        %{check: "a", status: "pass"},
        %{check: "b", status: "warn", detail: "heads up"}
      ]

      assert OAuth2ClientValidator.overall_status(checks) == "warning"
    end

    test "returns 'valid' for empty list" do
      assert OAuth2ClientValidator.overall_status([]) == "valid"
    end
  end

  # ── Tests: count_statuses ────────────────────────────────────────────────

  describe "count_statuses/1" do
    test "counts pass, fail, warn correctly" do
      checks = [
        %{check: "a", status: "pass"},
        %{check: "b", status: "pass"},
        %{check: "c", status: "fail", detail: "nope"},
        %{check: "d", status: "warn", detail: "maybe"}
      ]

      assert OAuth2ClientValidator.count_statuses(checks) == %{pass: 2, fail: 1, warn: 1}
    end

    test "returns zeros for empty list" do
      assert OAuth2ClientValidator.count_statuses([]) == %{pass: 0, fail: 0, warn: 0}
    end
  end

  # ── Tests: edge cases ────────────────────────────────────────────────────

  describe "edge cases" do
    test "handles client with no redirect URIs (backend)" do
      {:ok, cc} = GrantType.new(:client_credentials)

      client =
        build_client(
          client_type: :confidential,
          grant_types: [cc],
          redirect_uris: [],
          allowed_scopes: []
        )

      checks = OAuth2ClientValidator.run(client)
      assert %{check: "client_active", status: "pass"} in checks

      openid_check = Enum.find(checks, &(&1.check == "has_openid_scope"))
      assert openid_check.status == "fail"
    end

    test "handles mixed http/https redirect URIs" do
      setup_cors(["http://app.zea.localhost", "https://app.zea.cl"])

      setup_csp(
        "default-src 'self'; form-action 'self' http://*.zea.localhost:* https://*.zea.cl"
      )

      {:ok, uri_http} = RedirectUri.new("http://app.zea.localhost/callback")
      {:ok, uri_https} = RedirectUri.new("https://app.zea.cl/callback")
      client = build_client(redirect_uris: [uri_http, uri_https])

      checks = OAuth2ClientValidator.run(client)
      assert Enum.all?(Enum.filter(checks, &(&1.check == "cors_origins")), &(&1.status == "pass"))

      assert Enum.all?(
               Enum.filter(checks, &(&1.check == "csp_form_action")),
               &(&1.status == "pass")
             )
    end
  end
end
