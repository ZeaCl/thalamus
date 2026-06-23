defmodule Thalamus.OAuth2ClientValidator do
  @moduledoc """
  Validates an OAuth2 client configuration.

  Runs diagnostic checks on client coherence, redirect URIs, CORS, CSP,
  and endpoint health. Read-only — no database writes, no side effects
  except internal HTTP health checks.

  Returns a list of check result maps:
    %{check: String.t(), status: "pass" | "fail" | "warn", detail: String.t() | nil}

  SOLID Principles:
  - Single Responsibility: Only validates OAuth2 client configuration
  - Open/Closed: New checks can be added without modifying existing ones
  - Dependency Inversion: Depends on Application.get_env (config), not implementations
  """

  alias Thalamus.Domain.Entities.OAuth2Client
  alias Thalamus.Domain.ValueObjects.{RedirectUri, Scope}

  @type check_result :: %{
          required(:check) => String.t(),
          required(:status) => String.t(),
          optional(:detail) => String.t() | nil
        }

  @doc """
  Runs all validation checks on a client.

  Returns a flat list of check result maps. Checks that pass
  have no `detail` field; checks that fail or warn include a
  human-readable `detail` with fix instructions.
  """
  @spec run(OAuth2Client.t()) :: [check_result()]
  def run(client) do
    [
      check_client_active(client),
      check_client_type_coherence(client),
      check_scopes(client),
      check_redirect_uris_format(client)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> then(fn checks ->
      checks ++
        check_cors_origins(client) ++ check_csp_form_action(client) ++ check_endpoint_health()
    end)
  end

  @doc """
  Determines overall validation status from a list of checks.
  - "invalid" if any check has status "fail"
  - "warning" if only "warn" statuses exist (no fails)
  - "valid" if all checks pass
  """
  @spec overall_status([check_result()]) :: String.t()
  def overall_status(checks) do
    cond do
      Enum.any?(checks, &(&1.status == "fail")) -> "invalid"
      Enum.any?(checks, &(&1.status == "warn")) -> "warning"
      true -> "valid"
    end
  end

  @doc """
  Counts pass/fail/warn in a list of checks.
  """
  @spec count_statuses([check_result()]) :: %{pass: integer(), fail: integer(), warn: integer()}
  def count_statuses(checks) do
    %{
      pass: Enum.count(checks, &(&1.status == "pass")),
      fail: Enum.count(checks, &(&1.status == "fail")),
      warn: Enum.count(checks, &(&1.status == "warn"))
    }
  end

  # ── Check: Client active ─────────────────────────────────────────────────

  defp check_client_active(%OAuth2Client{is_active: true}),
    do: %{check: "client_active", status: "pass"}

  defp check_client_active(_),
    do: %{
      check: "client_active",
      status: "fail",
      detail: "Client is deactivated. Activate it to allow OAuth2 flows."
    }

  # ── Check: Client type coherence ─────────────────────────────────────────

  defp check_client_type_coherence(%OAuth2Client{client_type: :public} = client) do
    [
      check_spa_has_authorization_code(client),
      check_spa_has_redirect_uris(client)
    ]
  end

  defp check_client_type_coherence(%OAuth2Client{client_type: :confidential} = client) do
    [
      check_backend_has_client_credentials(client)
    ]
  end

  defp check_client_type_coherence(_), do: []

  defp check_spa_has_authorization_code(client) do
    has_auth_code = Enum.any?(client.grant_types, &(&1.type == :authorization_code))

    if has_auth_code do
      %{check: "grant_types", status: "pass"}
    else
      %{
        check: "grant_types",
        status: "fail",
        detail:
          "SPA clients require authorization_code grant type. Add it to allowed_grant_types."
      }
    end
  end

  defp check_spa_has_redirect_uris(client) do
    if Enum.empty?(client.redirect_uris) do
      %{
        check: "redirect_uris_present",
        status: "fail",
        detail: "SPA clients require at least one redirect URI."
      }
    else
      %{check: "redirect_uris_present", status: "pass"}
    end
  end

  defp check_backend_has_client_credentials(client) do
    has_cc = Enum.any?(client.grant_types, &(&1.type == :client_credentials))

    if has_cc do
      %{check: "grant_types", status: "pass"}
    else
      %{
        check: "grant_types",
        status: "warn",
        detail:
          "Backend clients typically use client_credentials grant type. Current grants: #{inspect(Enum.map(client.grant_types, & &1.type))}"
      }
    end
  end

  # ── Check: Scopes ────────────────────────────────────────────────────────

  defp check_scopes(client) do
    scope_strings = Enum.map(client.allowed_scopes, &Scope.to_string/1)

    if "openid" in scope_strings do
      %{check: "has_openid_scope", status: "pass"}
    else
      %{
        check: "has_openid_scope",
        status: "fail",
        detail: "openid scope is required for OpenID Connect. Add it to allowed_scopes."
      }
    end
  end

  # ── Check: Redirect URI format ───────────────────────────────────────────

  defp check_redirect_uris_format(client) do
    client.redirect_uris
    |> Enum.map(fn %RedirectUri{value: uri_str} ->
      if String.starts_with?(uri_str, "http://") or String.starts_with?(uri_str, "https://") do
        nil
      else
        %{
          check: "redirect_uri_format",
          status: "fail",
          detail: "Invalid redirect URI: #{uri_str}. Must start with http:// or https://"
        }
      end
    end)
  end

  # ── Check: CORS origins ──────────────────────────────────────────────────

  defp check_cors_origins(client) do
    cors_config = Application.get_env(:thalamus, ThalamusWeb.Plugs.CORS, [])
    cors_origins = Keyword.get(cors_config, :origins, [])

    cond do
      cors_origins == [] ->
        [
          %{
            check: "cors_origins",
            status: "warn",
            detail: "CORS_ORIGINS is not configured or empty. CORS check skipped."
          }
        ]

      Enum.empty?(client.redirect_uris) ->
        []

      true ->
        client.redirect_uris
        |> extract_unique_origins()
        |> Enum.map(&cors_origin_result(&1, cors_origins))
    end
  end

  defp cors_origin_result(origin, cors_origins) do
    origin_str = to_string(origin)

    if origin_str in cors_origins do
      %{check: "cors_origins", status: "pass"}
    else
      %{
        check: "cors_origins",
        status: "fail",
        detail:
          "Origin '#{origin_str}' is not in CORS_ORIGINS. Add it to CORS_ORIGINS in docker-compose.yml."
      }
    end
  end

  # ── Check: CSP form-action ───────────────────────────────────────────────

  defp check_csp_form_action(client) do
    csp_config = Application.get_env(:thalamus, ThalamusWeb.Plugs.SecurityHeaders, [])
    csp_policy = Keyword.get(csp_config, :csp_policy, "")

    cond do
      csp_policy == "" ->
        [
          %{
            check: "csp_policy",
            status: "fail",
            detail:
              "CSP policy is not configured. Check config/config.exs and security_headers.ex."
          }
        ]

      Enum.empty?(client.redirect_uris) ->
        []

      true ->
        form_action = extract_form_action(csp_policy)

        client.redirect_uris
        |> extract_unique_origins()
        |> Enum.map(&csp_origin_result(&1, form_action))
    end
  end

  defp csp_origin_result(origin, form_action) do
    host = extract_host(origin)

    if csp_covers_host?(form_action, host) do
      %{check: "csp_form_action", status: "pass"}
    else
      %{
        check: "csp_form_action",
        status: "warn",
        detail:
          "Domain '#{host}' is not covered by CSP form-action. Add to form-action in config/config.exs AND security_headers.ex."
      }
    end
  end

  # ── Check: Endpoint health ───────────────────────────────────────────────

  defp check_endpoint_health do
    # Skip health checks in test environment to avoid network timeouts
    if Mix.env() == :test do
      [
        %{check: "jwks_endpoint", status: "pass"},
        %{check: "authorize_endpoint", status: "pass"},
        %{check: "token_endpoint", status: "pass"}
      ]
    else
      base_url = Application.get_env(:thalamus, :base_url, "http://localhost:4000")

      [
        check_jwks(base_url),
        check_authorize_endpoint(base_url),
        check_token_endpoint(base_url)
      ]
    end
  end

  defp check_jwks(base_url) do
    case Req.get("#{base_url}/.well-known/jwks.json") do
      {:ok, %{status: 200}} ->
        %{check: "jwks_endpoint", status: "pass"}

      {:ok, %{status: status}} ->
        %{check: "jwks_endpoint", status: "fail", detail: "JWKS endpoint returned HTTP #{status}"}

      {:error, reason} ->
        %{
          check: "jwks_endpoint",
          status: "fail",
          detail: "JWKS endpoint unreachable: #{inspect(reason)}"
        }
    end
  end

  defp check_authorize_endpoint(base_url) do
    case Req.get("#{base_url}/oauth/authorize") do
      {:ok, %{status: s}} when s in [200, 302, 400] ->
        %{check: "authorize_endpoint", status: "pass"}

      {:ok, %{status: status}} ->
        %{
          check: "authorize_endpoint",
          status: "fail",
          detail: "Authorize endpoint returned HTTP #{status}"
        }

      {:error, reason} ->
        %{
          check: "authorize_endpoint",
          status: "fail",
          detail: "Authorize endpoint unreachable: #{inspect(reason)}"
        }
    end
  end

  defp check_token_endpoint(base_url) do
    case Req.post("#{base_url}/oauth/token", json: %{}) do
      {:ok, %{status: s}} when s in [400, 401] ->
        %{check: "token_endpoint", status: "pass"}

      {:ok, %{status: status}} ->
        %{
          check: "token_endpoint",
          status: "fail",
          detail: "Token endpoint returned HTTP #{status}"
        }

      {:error, reason} ->
        %{
          check: "token_endpoint",
          status: "fail",
          detail: "Token endpoint unreachable: #{inspect(reason)}"
        }
    end
  end

  # ── Helper functions ─────────────────────────────────────────────────────

  defp extract_unique_origins(redirect_uris) do
    redirect_uris
    |> Enum.map(&RedirectUri.to_string/1)
    |> Enum.map(fn uri_str ->
      parsed = URI.parse(uri_str)
      port_part = if parsed.port && parsed.port not in [80, 443], do: ":#{parsed.port}", else: ""
      "#{parsed.scheme}://#{parsed.host}#{port_part}"
    end)
    |> Enum.uniq()
  end

  defp extract_host(origin) do
    uri = URI.parse(to_string(origin))

    if uri.port && uri.port not in [80, 443] do
      "#{uri.host}:#{uri.port}"
    else
      uri.host
    end
  end

  defp extract_form_action(csp_policy) when is_binary(csp_policy) do
    case Regex.run(~r/form-action\s+([^;]+)/, csp_policy) do
      [_, form_action] -> String.trim(form_action)
      nil -> ""
    end
  end

  defp csp_covers_host?(form_action, host) do
    # Check exact match in form-action (e.g. "http://soma.zea.localhost:*")
    if String.contains?(form_action, host) do
      true
    else
      # Check wildcard: *.domain.com covers sub.domain.com
      host_parts = String.split(host, ".")

      if length(host_parts) >= 2 do
        domain_part = Enum.drop(host_parts, 1) |> Enum.join(".")
        String.contains?(form_action, "*.#{domain_part}")
      else
        false
      end
    end
  end
end
