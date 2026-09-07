defmodule Thalamus.Infrastructure.Adapters.SocialAuth.GitHubAdapter do
  @moduledoc """
  GitHub OAuth2 adapter implementing SocialAuthProvider.
  """

  @behaviour Thalamus.Application.Ports.SocialAuthProvider

  require Logger

  @auth_url "https://github.com/login/oauth/authorize"
  @token_url "https://github.com/login/oauth/access_token"
  @user_url "https://api.github.com/user"
  @emails_url "https://api.github.com/user/emails"

  @impl true
  def get_authorization_url(state, opts \\ []) do
    client_id = get_config(:client_id, opts)
    redirect_uri = get_config(:redirect_uri, opts)

    if is_nil(client_id) or client_id == "" do
      {:error, :missing_github_client_id}
    else
      params = %{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "scope" => "read:user user:email",
        "state" => state
      }

      url = @auth_url <> "?" <> URI.encode_query(params)
      {:ok, url}
    end
  end

  @impl true
  def exchange_code(code, opts \\ []) do
    client_id = get_config(:client_id, opts)
    client_secret = get_config(:client_secret, opts)
    redirect_uri = get_config(:redirect_uri, opts)
    http_client = Keyword.get(opts, :http_client, Req)

    cond do
      is_nil(client_id) or client_id == "" ->
        {:error, :missing_github_client_id}

      is_nil(client_secret) or client_secret == "" ->
        {:error, :missing_github_client_secret}

      true ->
        token_payload = %{
          "code" => code,
          "client_id" => client_id,
          "client_secret" => client_secret,
          "redirect_uri" => redirect_uri
        }

        headers = [
          {"accept", "application/json"},
          {"user-agent", "Thalamus-Auth-Service"}
        ]

        case http_client.post(@token_url, form: token_payload, headers: headers) do
          {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
            fetch_user_profile(access_token, http_client)

          {:ok, %{status: status, body: body}} ->
            Logger.error("GitHub token exchange failed (#{status}): #{inspect(body)}")
            {:error, :token_exchange_failed}

          {:error, reason} ->
            Logger.error("GitHub token request failed: #{inspect(reason)}")
            {:error, :network_error}
        end
    end
  end

  defp fetch_user_profile(access_token, http_client) do
    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"accept", "application/vnd.github+json"},
      {"user-agent", "Thalamus-Auth-Service"}
    ]

    with {:ok, %{status: 200, body: user_data}} <- http_client.get(@user_url, headers: headers),
         {:ok, email, email_verified} <-
           fetch_primary_email(access_token, http_client, user_data["email"]) do
      uid = to_string(user_data["id"])
      name = user_data["name"] || user_data["login"]
      avatar = user_data["avatar_url"]

      clean_raw = Map.drop(user_data, ["access_token", "token", "refresh_token", "id_token"])

      {:ok,
       %{
         provider: "github",
         provider_uid: uid,
         email: email,
         email_verified: email_verified,
         name: name,
         avatar_url: avatar,
         raw: clean_raw
       }}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("GitHub user fetch failed (#{status}): #{inspect(body)}")
        {:error, :userinfo_failed}

      {:error, reason} ->
        Logger.error("GitHub user request error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_primary_email(access_token, http_client, default_email) do
    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"accept", "application/vnd.github+json"},
      {"user-agent", "Thalamus-Auth-Service"}
    ]

    case http_client.get(@emails_url, headers: headers) do
      {:ok, %{status: 200, body: emails}} when is_list(emails) ->
        primary_verified = Enum.find(emails, &(&1["primary"] == true and &1["verified"] == true))
        any_verified = Enum.find(emails, &(&1["verified"] == true))

        primary =
          primary_verified ||
            any_verified ||
            Enum.find(emails, &(&1["primary"] == true)) ||
            List.first(emails)

        if primary do
          {:ok, primary["email"], primary["verified"] == true}
        else
          {:ok, default_email, false}
        end

      _ ->
        {:ok, default_email, false}
    end
  end

  defp get_config(key, opts) do
    Keyword.get(opts, key) ||
      Application.get_env(:thalamus, :github_auth, [])[key] ||
      System.get_env(env_var_name(key)) ||
      default_config(key)
  end

  defp env_var_name(:client_id), do: "GITHUB_CLIENT_ID"
  defp env_var_name(:client_secret), do: "GITHUB_CLIENT_SECRET"
  defp env_var_name(:redirect_uri), do: "GITHUB_REDIRECT_URI"
  defp env_var_name(_), do: ""

  defp default_config(:redirect_uri) do
    ThalamusWeb.URLHelpers.resolve_social_redirect_uri(nil, "github")
  end

  defp default_config(_), do: nil
end
