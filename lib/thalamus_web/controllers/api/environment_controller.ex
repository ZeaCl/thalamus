defmodule ThalamusWeb.API.EnvironmentController do
  @moduledoc """
  REST API Controller for managing Organization Environments.

  Provides endpoints to list, create, view, update, delete, and set default environments.
  """
  use ThalamusWeb, :controller

  alias Thalamus.Application.UseCases.ManageEnvironments

  @doc """
  GET /api/organizations/:organization_id/environments
  Lists all environments for the organization.
  """
  def index(conn, %{"organization_id" => org_id} = params) do
    filters = %{
      include_archived: Map.get(params, "include_archived", "false") == "true",
      status: Map.get(params, "status")
    }

    case ManageEnvironments.list_environments(org_id, filters) do
      {:ok, environments} ->
        render(conn, :index, environments: environments)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to list environments", details: inspect(reason)})
    end
  end

  @doc """
  GET /api/organizations/:organization_id/environments/:id
  Gets a specific environment by slug or ID.
  """
  def show(conn, %{"organization_id" => org_id, "id" => id_or_slug}) do
    case ManageEnvironments.get_environment(org_id, id_or_slug) do
      {:ok, env} ->
        render(conn, :show, environment: env)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Environment not found"})
    end
  end

  @doc """
  POST /api/organizations/:organization_id/environments
  Creates a new environment for the organization.
  """
  def create(conn, %{"organization_id" => org_id} = params) do
    env_params = Map.get(params, "environment", params)

    case ManageEnvironments.create_environment(org_id, env_params) do
      {:ok, env} ->
        conn
        |> put_status(:created)
        |> render(:show, environment: env)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: format_changeset_errors(changeset)})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  PUT/PATCH /api/organizations/:organization_id/environments/:id
  Updates an existing environment.
  """
  def update(conn, %{"organization_id" => org_id, "id" => id_or_slug} = params) do
    env_params = Map.get(params, "environment", params)

    case ManageEnvironments.update_environment(org_id, id_or_slug, env_params) do
      {:ok, env} ->
        render(conn, :show, environment: env)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Environment not found"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validation failed", details: format_changeset_errors(changeset)})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Update failed", details: inspect(reason)})
    end
  end

  @doc """
  DELETE /api/organizations/:organization_id/environments/:id
  Archives or deletes an environment.
  """
  def delete(conn, %{"organization_id" => org_id, "id" => id_or_slug} = params) do
    force = Map.get(params, "force", "false") == "true"

    case ManageEnvironments.delete_environment(org_id, id_or_slug, force: force) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:ok, _archived_env} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Environment not found"})

      {:error, :cannot_delete_default_environment} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Cannot delete the default environment"})

      {:error, :cannot_delete_production_environment} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Cannot delete production environment without force=true"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Delete failed", details: inspect(reason)})
    end
  end

  @doc """
  POST /api/organizations/:organization_id/environments/:id/default
  Sets an environment as the default environment for an organization.
  """
  def set_default(conn, %{"organization_id" => org_id, "id" => id_or_slug}) do
    case ManageEnvironments.update_environment(org_id, id_or_slug, %{is_default: true}) do
      {:ok, env} ->
        render(conn, :show, environment: env)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Environment not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to set default", details: inspect(reason)})
    end
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
