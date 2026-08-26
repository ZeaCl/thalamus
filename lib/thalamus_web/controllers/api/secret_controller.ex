defmodule ThalamusWeb.API.SecretController do
  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.ManageSecrets
  alias Thalamus.Application.UseCases.ResolveAgentSecret

  @doc """
  Lists secrets for the current user or an organization (if user is member).
  """
  def index(conn, %{"owner_type" => owner_type, "owner_id" => owner_id} = params) do
    # Here we would normally verify that conn.assigns.current_user has access to owner_id
    # For now, we just list them.
    raw_env = Map.get(params, "environment_id") || Map.get(params, "env")
    org_id = if owner_type == "organization", do: owner_id, else: nil
    environment_id = resolve_env_id(org_id, raw_env)

    secrets = ManageSecrets.list_by_owner(owner_type, owner_id, environment_id)
    render(conn, :index, secrets: secrets)
  end

  @doc """
  Creates a new secret.
  """
  def create(conn, %{"secret" => secret_params}) do
    case ManageSecrets.create_secret(secret_params) do
      {:ok, secret} ->
        conn
        |> put_status(:created)
        |> render(:show, secret: secret)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a secret.
  """
  def delete(conn, %{"id" => id}) do
    case ManageSecrets.delete_secret(id) do
      {:ok, _secret} ->
        send_resp(conn, :no_content, "")

      {:error, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Resolves a secret for an agent given provider, org_id, and user_id.
  """
  def resolve(conn, %{"provider" => provider} = params) do
    org_id =
      case Map.get(params, "org_id") do
        "" -> nil
        id -> id
      end

    user_id =
      case Map.get(params, "user_id") do
        "" -> nil
        id -> id
      end

    raw_env =
      case Map.get(params, "environment_id") || Map.get(params, "env") do
        "" -> nil
        env -> env
      end

    environment_id = resolve_env_id(org_id, raw_env)

    prefer_user = Map.get(params, "prefer_user", "false") == "true"

    case ResolveAgentSecret.execute(provider, org_id, user_id,
           prefer_user: prefer_user,
           environment_id: environment_id
         ) do
      {:ok, secret} ->
        # We render the secret AND its decrypted value here because it's requested by an internal service (Glia)
        # In a real microservices architecture, this endpoint would be protected by mTLS or an internal Agent API Key.
        # For ZEA platform, we return it as JSON.
        json(conn, %{
          id: secret.id,
          provider: secret.provider,
          owner_type: secret.owner_type,
          owner_id: secret.owner_id,
          name: secret.name,
          environment_id: secret.environment_id,
          # decrypted thanks to cloak!
          value: secret.value
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Secret not found"})
    end
  end

  defp resolve_env_id(nil, env), do: env
  defp resolve_env_id(_org_id, nil), do: nil

  defp resolve_env_id(org_id, env) do
    case Ecto.UUID.cast(env) do
      {:ok, uuid} ->
        uuid

      :error ->
        case Thalamus.Application.UseCases.ManageEnvironments.get_environment(org_id, env) do
          {:ok, %{id: env_id}} -> env_id
          _ -> nil
        end
    end
  end
end
