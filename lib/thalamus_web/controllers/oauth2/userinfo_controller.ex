defmodule ThalamusWeb.OAuth2.UserinfoController do
  @moduledoc """
  OAuth2/OpenID Connect UserInfo Endpoint Controller.

  Implements RFC 6749 & OpenID Connect UserInfo Endpoint.
  Returns user information based on the provided access token.
  """

  use ThalamusWeb, :controller

  require Logger

  alias Thalamus.Infrastructure.Repositories.{
    PostgreSQLTokenRepository,
    PostgreSQLUserRepository,
    PostgreSQLOrganizationRepository
  }

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
         {:ok, validation_result} <-
           Thalamus.Application.UseCases.ValidateToken.execute(token, %{
             token_repository: PostgreSQLTokenRepository
           }),
         true <- validation_result.valid and validation_result.active,
         user_id_string =
           (case validation_result.user_id do
              %{__struct__: _} -> to_string(validation_result.user_id)
              str when is_binary(str) -> str
            end),
         {:ok, user_id_vo} <- Thalamus.Domain.ValueObjects.UserId.from_string(user_id_string),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id_vo),
         {:ok, user_schema} <- get_user_schema(user_id_vo) do
      # Load all organizations where the user is a member
      user_id_str = user_id_string

      all_orgs = Repo.all(Thalamus.Infrastructure.Persistence.Schemas.OrganizationSchema)

      user_orgs =
        Enum.filter(all_orgs, fn org ->
          members = org.members || []
          Enum.any?(members, fn m -> m["user_id"] == user_id_str end)
        end)

      # Primary organization (may be nil)
      primary_org =
        case user_schema.organization_id do
          nil ->
            nil

          org_id_str ->
            case OrganizationId.from_string(org_id_str) do
              {:ok, org_id} ->
                case PostgreSQLOrganizationRepository.find_by_id(org_id) do
                  {:ok, org} -> org
                  _ -> nil
                end

              _ ->
                nil
            end
        end

      orgs_json =
        Enum.map(user_orgs, fn org ->
          %{
            id: org.id,
            name: org.name,
            slug: generate_slug(org.name)
          }
        end)

      # Return user info with nested organization object and all memberships
      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("pragma", "no-cache")
      |> json(%{
        sub: user.id,
        email: user.email,
        email_verified: user.verified_at != nil,
        updated_at: DateTime.to_unix(user.updated_at),
        organization:
          if primary_org do
            %{
              id: OrganizationId.to_string(primary_org.id),
              name: primary_org.name,
              slug: generate_slug(primary_org.name)
            }
          else
            # Fallback: use first member organization as primary
            case user_orgs do
              [first | _] ->
                %{
                  id: first.id,
                  name: first.name,
                  slug: generate_slug(first.name)
                }

              [] ->
                %{}
            end
          end,
        organizations: orgs_json
      })
    else
      false ->
        Logger.warning("UserInfo validation_result: valid=#{inspect(false)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "Invalid or expired token"})

      {:error, reason} ->
        Logger.error("UserInfo validation error: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", error_description: "Could not validate access token"})

      error ->
        Logger.error("UserInfo unexpected error: #{inspect(error)}")

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
    user_id_string =
      case user_id_vo do
        %{__struct__: _} -> to_string(user_id_vo)
        str when is_binary(str) -> str
      end

    case Repo.get(UserSchema, user_id_string) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema}
    end
  end
end
