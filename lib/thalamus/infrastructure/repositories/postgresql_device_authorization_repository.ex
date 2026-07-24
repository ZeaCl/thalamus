defmodule Thalamus.Infrastructure.Repositories.PostgreSQLDeviceAuthorizationRepository do
  @moduledoc """
  PostgreSQL implementation of DeviceAuthorizationRepository port.

  SOLID Principles Applied:
  - Dependency Inversion: Implements port defined in Application layer
  - Single Responsibility: Only handles device authorization persistence
  """

  @behaviour Thalamus.Application.Ports.DeviceAuthorizationRepository

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.DeviceAuthorization
  alias Thalamus.Infrastructure.Persistence.Schemas.DeviceAuthorizationSchema

  @impl true
  def store(%DeviceAuthorization{} = da) do
    DeviceAuthorizationSchema.create_changeset(%{
      id: da.id,
      device_code: da.device_code,
      user_code: da.user_code,
      client_id: da.client_id,
      scopes: da.scopes,
      status: to_string(da.status),
      expires_at: da.expires_at,
      interval: da.interval,
      inserted_at: da.inserted_at
    })
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def find_by_device_code(device_code) do
    case Repo.get_by(DeviceAuthorizationSchema, device_code: device_code) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_entity(schema)}
    end
  end

  @impl true
  def find_by_user_code(user_code) do
    case Repo.get_by(DeviceAuthorizationSchema, user_code: user_code) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_entity(schema)}
    end
  end

  @impl true
  def authorize(%DeviceAuthorization{} = da, user_id) do
    schema = Repo.get!(DeviceAuthorizationSchema, da.id)

    schema
    |> DeviceAuthorizationSchema.authorize_changeset(user_id)
    |> Repo.update()
    |> case do
      {:ok, schema} -> {:ok, to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def record_poll(%DeviceAuthorization{} = da) do
    schema = Repo.get!(DeviceAuthorizationSchema, da.id)

    schema
    |> DeviceAuthorizationSchema.poll_changeset()
    |> Repo.update()
    |> case do
      {:ok, schema} -> {:ok, to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def expire(%DeviceAuthorization{} = da) do
    schema = Repo.get!(DeviceAuthorizationSchema, da.id)

    schema
    |> DeviceAuthorizationSchema.expire_changeset()
    |> Repo.update()
    |> case do
      {:ok, schema} -> {:ok, to_entity(schema)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def cleanup_expired do
    import Ecto.Query

    now = DateTime.utc_now()

    query =
      from(da in DeviceAuthorizationSchema,
        where: da.expires_at < ^now and da.status != "expired"
      )

    {count, _} = Repo.update_all(query, set: [status: "expired"])
    {:ok, count}
  end

  # ── Private ──────────────────────────────────────────────────

  defp to_entity(%DeviceAuthorizationSchema{} = schema) do
    %DeviceAuthorization{
      id: schema.id,
      device_code: schema.device_code,
      user_code: schema.user_code,
      client_id: schema.client_id,
      scopes: schema.scopes || [],
      user_id: schema.user_id,
      status: String.to_existing_atom(schema.status),
      expires_at: schema.expires_at,
      last_polled_at: schema.last_polled_at,
      interval: schema.interval,
      authorized_at: schema.authorized_at,
      inserted_at: schema.inserted_at
    }
  end
end
