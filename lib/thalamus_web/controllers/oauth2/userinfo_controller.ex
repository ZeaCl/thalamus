defmodule ThalamusWeb.OAuth2.UserinfoController do
  @moduledoc """
  OAuth2/OpenID Connect UserInfo Endpoint Controller.

  Implements RFC 6749 & OpenID Connect UserInfo Endpoint.
  Returns user information based on the provided access token.
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.{PostgreSQLTokenRepository, PostgreSQLUserRepository, PostgreSQLOrganizationRepository}
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema
  alias Thalamus.Domain.ValueObjects.OrganizationId
  alias Thalamus.Repo

  @doc """
  GET /oauth/userinfo

  Returns information about the authenticated user.
  Requires Bearer token in Authorization header.
  """
  def show(conn, _params) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, token_data} <- PostgreSQLTokenRepository.find(token),
         :ok <- validate_token_type(token_data),
         :ok <- validate_token_not_expired(token_data),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(token_data.user_id),
         {:ok, user_schema} <- get_user_schema(token_data.user_id),
         {:ok, org_id} <- OrganizationId.from_string(user_schema.organization_id),
         {:ok, organization} <- PostgreSQLOrganizationRepository.find_by_id(org_id) do

      # Return user info with nested organization object
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("pragma", "no-cache")
      |> json(%{
        sub: user.id,
        email: user.email,
        email_verified: user.verified_at != nil,
        updated_at: DateTime.to_unix(user.updated_at),
        organization: %{
          id: OrganizationId.to_string(organization.id),
          name: organization.name,
          slug: generate_slug(organization.name)
        }
      })
    else
      {:error, :no_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "No access token provided"})

      {:error, :not_found} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "Invalid or revoked access token"})

      {:error, :wrong_token_type} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "Token is not an access token"})

      {:error, :expired} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "Access token has expired"})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "Could not validate access token"})
    end
  end

  # Private helper functions

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :no_token}
    end
  end

  defp validate_token_type(%{type: :access_token}), do: :ok
  defp validate_token_type(_), do: {:error, :wrong_token_type}

  defp validate_token_not_expired(%{expires_at: expires_at}) do
    now = DateTime.utc_now()
    if DateTime.compare(expires_at, now) == :gt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp get_user_schema(user_id_vo) do
    user_id_string = case user_id_vo do
      %{__struct__: _} -> to_string(user_id_vo)
      str when is_binary(str) -> str
    end

    case Repo.get(UserSchema, user_id_string) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end
end
