defmodule Thalamus.Infrastructure.Repositories.PostgresqlAgentTokenRepository do
  @moduledoc """
  PostgreSQL implementation of AgentTokenRepository port.

  Handles persistence of agent tokens using Ecto and PostgreSQL.
  Converts between domain entities and database schemas.

  SOLID Principles:
  - Single Responsibility: Only handles agent token persistence
  - Dependency Inversion: Implements port defined by application layer
  """

  @behaviour Thalamus.Application.Ports.AgentTokenRepository

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}
  alias Thalamus.Infrastructure.Persistence.Schemas.AgentTokenSchema

  @impl true
  def save(%AgentToken{} = token) do
    # Check if token already exists in database
    case Repo.get(AgentTokenSchema, token.id) do
      nil ->
        # Insert new token
        changeset = to_insert_changeset(token)

        case Repo.insert(changeset) do
          {:ok, schema} -> {:ok, to_domain(schema)}
          {:error, changeset} -> {:error, changeset}
        end

      existing_schema ->
        # Update existing token
        changeset = to_update_changeset(existing_schema, token)

        case Repo.update(changeset) do
          {:ok, schema} -> {:ok, to_domain(schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def find_by_id(id) when is_binary(id) do
    case Repo.get(AgentTokenSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def find_by_access_token(access_token) when is_binary(access_token) do
    AgentTokenSchema
    |> where([t], t.access_token == ^access_token)
    |> where([t], is_nil(t.revoked_at))
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> {:ok, to_domain(schema)}
    end
  end

  @impl true
  def find_by_organization(organization_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    include_revoked = Keyword.get(opts, :include_revoked, false)

    query =
      AgentTokenSchema
      |> where([t], t.organization_id == ^organization_id)
      |> limit(^limit)
      |> offset(^offset)
      |> order_by([t], desc: t.inserted_at)

    query =
      if include_revoked do
        query
      else
        where(query, [t], is_nil(t.revoked_at))
      end

    tokens =
      query
      |> Repo.all()
      |> Enum.map(&to_domain/1)

    {:ok, tokens}
  end

  @impl true
  def revoke(id, reason \\ nil) when is_binary(id) do
    case Repo.get(AgentTokenSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        changeset =
          AgentTokenSchema.update_changeset(schema, %{
            revoked_at: DateTime.truncate(DateTime.utc_now(), :second),
            revoke_reason: reason
          })

        case Repo.update(changeset) do
          {:ok, updated_schema} -> {:ok, to_domain(updated_schema)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @impl true
  def revoke_delegation_chain(parent_id, reason \\ nil) when is_binary(parent_id) do
    # First revoke the parent
    case revoke(parent_id, reason) do
      {:ok, _} ->
        # Then find and revoke all descendants
        count = revoke_descendants(parent_id, reason)
        # +1 for the parent
        {:ok, count + 1}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def count_active_by_organization(organization_id) when is_binary(organization_id) do
    now = DateTime.utc_now()

    count =
      AgentTokenSchema
      |> where([t], t.organization_id == ^organization_id)
      |> where([t], is_nil(t.revoked_at))
      |> where([t], t.expires_at > ^now)
      |> Repo.aggregate(:count)

    {:ok, count}
  end

  # Private helper functions

  # Recursively revoke all descendants of a parent token
  defp revoke_descendants(parent_id, reason) do
    # Find all direct children
    children =
      AgentTokenSchema
      |> where([t], t.parent_agent_id == ^parent_id)
      |> where([t], is_nil(t.revoked_at))
      |> Repo.all()

    # Revoke each child and their descendants
    Enum.reduce(children, 0, fn child, acc ->
      # Revoke this child
      {:ok, _} = revoke(child.id, reason)

      # Recursively revoke its descendants
      descendant_count = revoke_descendants(child.id, reason)

      # Count this child + its descendants
      acc + 1 + descendant_count
    end)
  end

  defp to_insert_changeset(%AgentToken{} = token) do
    attrs = %{
      client_id:
        if(token.client_id, do: String.replace_prefix(token.client_id, "client_", ""), else: nil),
      organization_id:
        if(token.organization_id,
          do: String.replace_prefix(token.organization_id, "org_", ""),
          else: nil
        ),
      access_token: generate_access_token(),
      agent_type: AgentType.to_string(token.agent_type),
      task_id: TaskId.to_string(token.task_id),
      task_description: token.task_description,
      scopes: token.scopes,
      parent_agent_id: token.delegation_chain.parent_token_id,
      delegation_chain: delegation_chain_to_map(token.delegation_chain),
      delegation_depth: token.delegation_chain.depth,
      delegator_user_id:
        if(token.delegator_user_id,
          do: String.replace_prefix(token.delegator_user_id, "user_", ""),
          else: nil
        ),
      expires_in: token.expires_in,
      expires_at: DateTime.truncate(AgentToken.expires_at(token), :second),
      revoked_at: truncate_datetime(token.revoked_at),
      revoke_reason: token.revoke_reason,
      reason: token.reason
    }

    # Set the ID on the struct itself, not in attrs
    %AgentTokenSchema{id: token.id}
    |> AgentTokenSchema.changeset(attrs)
  end

  # Converts domain entity to Ecto changeset for update
  defp to_update_changeset(%AgentTokenSchema{} = schema, %AgentToken{} = token) do
    # For updates, we only allow updating revocation fields
    # Access token and other core fields should not change
    attrs = %{
      revoked_at: truncate_datetime(token.revoked_at),
      revoke_reason: token.revoke_reason
    }

    AgentTokenSchema.update_changeset(schema, attrs)
  end

  # Helper to safely truncate datetime (handles nil)
  defp truncate_datetime(nil), do: nil
  defp truncate_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :second)

  # Converts Ecto schema to domain entity
  defp to_domain(%AgentTokenSchema{} = schema) do
    {:ok, agent_type} = AgentType.new(schema.agent_type)
    {:ok, task_id} = TaskId.new(schema.task_id)
    {:ok, delegation_chain} = map_to_delegation_chain(schema.delegation_chain)

    # Calculate status based on revoked_at
    status = if schema.revoked_at, do: :revoked, else: :active

    %AgentToken{
      id: schema.id,
      client_id: schema.client_id,
      organization_id:
        if(schema.organization_id, do: "org_" <> schema.organization_id, else: nil),
      agent_type: agent_type,
      task_id: task_id,
      task_description: schema.task_description,
      scopes: schema.scopes,
      delegation_chain: delegation_chain,
      delegator_user_id: schema.delegator_user_id,
      expires_in: schema.expires_in,
      status: status,
      revoked_at: schema.revoked_at,
      revoke_reason: schema.revoke_reason,
      reason: schema.reason,
      created_at: schema.inserted_at
    }
  end

  # Converts DelegationChain value object to map for JSONB storage
  defp delegation_chain_to_map(%DelegationChain{} = chain) do
    %{
      "parent_token_id" => chain.parent_token_id,
      "depth" => chain.depth,
      "path" => chain.path
    }
  end

  # Converts JSONB map to DelegationChain value object
  defp map_to_delegation_chain(map) when is_map(map) do
    DelegationChain.new(%{
      parent_token_id: map["parent_token_id"],
      depth: map["depth"],
      path: map["path"] || []
    })
  end

  # Generates a cryptographically secure access token
  defp generate_access_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
