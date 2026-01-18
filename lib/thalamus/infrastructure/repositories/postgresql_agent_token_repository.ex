defmodule Thalamus.Infrastructure.Repositories.PostgreSQLAgentTokenRepository do
  @moduledoc """
  PostgreSQL implementation of the AgentTokenRepository port.

  This adapter handles agent-specific OAuth2 token storage and retrieval.
  It implements the AgentTokenRepository behaviour defined in the Application layer.

  SOLID Principles Applied:
  - Single Responsibility: Only handles agent token persistence
  - Dependency Inversion: Implements the port defined by Application layer
  - Interface Segregation: Implements only AgentTokenRepository interface

  Per 03-tasks.md Epic 2.3 specification.
  """

  @behaviour Thalamus.Application.Ports.AgentTokenRepository

  import Ecto.Query

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.TokenSchema
  alias Thalamus.Domain.Entities.AgentToken
  alias Thalamus.Domain.ValueObjects.{AgentType, TaskId, DelegationChain}

  @impl true
  def save(%AgentToken{} = token) do
    attrs = to_schema_attrs(token)

    changeset =
      if token.id do
        # Update existing token
        case Repo.get(TokenSchema, token.id) do
          nil -> TokenSchema.create_changeset(attrs)
          schema -> TokenSchema.create_changeset(Map.merge(schema, attrs))
        end
      else
        # Insert new token
        TokenSchema.create_changeset(attrs)
      end

    case Repo.insert_or_update(changeset) do
      {:ok, schema} -> to_domain(schema)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @impl true
  def find_by_id(id) when is_binary(id) do
    TokenSchema
    |> where([t], t.id == ^id)
    |> where([t], not is_nil(t.agent_type))
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> to_domain(schema)
    end
  end

  @impl true
  def find_by_access_token(access_token) when is_binary(access_token) do
    TokenSchema
    |> where([t], t.token == ^access_token)
    |> where([t], not is_nil(t.agent_type))
    |> where([t], t.revoked == false)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> to_domain(schema)
    end
  end

  @impl true
  def revoke(access_token) when is_binary(access_token) do
    TokenSchema
    |> where([t], t.token == ^access_token)
    |> where([t], not is_nil(t.agent_type))
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> TokenSchema.revoke_changeset()
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> to_domain(updated_schema)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @impl true
  def revoke_delegation_chain(user_id) when is_binary(user_id) do
    now = DateTime.utc_now()

    # Revoke all tokens where this user_id appears in the delegation chain
    {count, _} =
      TokenSchema
      |> where([t], not is_nil(t.agent_type))
      |> where([t], t.revoked == false)
      |> where([t], ^user_id in t.delegation_chain)
      |> Repo.update_all(set: [revoked: true, revoked_at: now])

    {:ok, count}
  end

  @impl true
  def find_by_organization(organization_id, opts \\ []) when is_binary(organization_id) do
    query =
      TokenSchema
      |> where([t], t.organization_id == ^organization_id)
      |> where([t], not is_nil(t.agent_type))

    # Apply filters
    query =
      case Keyword.get(opts, :agent_type) do
        nil -> query
        agent_type -> where(query, [t], t.agent_type == ^to_string(agent_type))
      end

    query =
      if Keyword.get(opts, :active_only, false) do
        now = DateTime.utc_now()

        query
        |> where([t], t.revoked == false)
        |> where([t], t.expires_at > ^now)
      else
        query
      end

    # Apply pagination
    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end

    query =
      case Keyword.get(opts, :offset) do
        nil -> query
        offset -> offset(query, ^offset)
      end

    # Order by created_at descending
    query = order_by(query, [t], desc: t.inserted_at)

    tokens =
      query
      |> Repo.all()
      |> Enum.map(fn schema ->
        case to_domain(schema) do
          {:ok, token} -> token
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, tokens}
  end

  @impl true
  def cleanup_expired do
    now = DateTime.utc_now()

    {count, _} =
      TokenSchema
      |> where([t], not is_nil(t.agent_type))
      |> where([t], t.expires_at < ^now)
      |> Repo.delete_all()

    {:ok, count}
  end

  # --- Private Helper Functions ---

  # Convert AgentToken entity to TokenSchema attributes
  defp to_schema_attrs(%AgentToken{} = token) do
    # Extract delegation chain as list of UUIDs
    delegation_chain_uuids =
      case token.delegation_chain do
        %DelegationChain{chain: chain} -> chain
        _ -> []
      end

    %{
      id: token.id,
      token: token.access_token,
      type: :access_token,
      agent_type: to_string(token.agent_type.value),
      task_id: task_id_to_string(token.task_id),
      scopes: token.scopes,
      delegation_chain: delegation_chain_uuids,
      organization_id: token.organization_id,
      client_id: token.client_id,
      expires_at: token.expires_at,
      revoked: token.revoked_at != nil,
      revoked_at: token.revoked_at,
      intent_description: token.reason,
      inserted_at: token.created_at
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Convert TokenSchema to AgentToken entity
  defp to_domain(%TokenSchema{} = schema) do
    # Reconstruct AgentType value object
    {:ok, agent_type} = AgentType.new(schema.agent_type)

    # Reconstruct TaskId value object if present
    task_id =
      if schema.task_id do
        case TaskId.new(schema.task_id) do
          {:ok, tid} -> tid
          _ -> nil
        end
      else
        nil
      end

    # Reconstruct DelegationChain value object
    delegation_chain =
      case schema.delegation_chain do
        nil ->
          {:ok, chain} = DelegationChain.root()
          chain

        [] ->
          {:ok, chain} = DelegationChain.root()
          chain

        chain_uuids when is_list(chain_uuids) ->
          case DelegationChain.new(chain_uuids) do
            {:ok, chain} -> chain
            _ ->
              {:ok, chain} = DelegationChain.root()
              chain
          end
      end

    # Build AgentToken entity
    attrs = %{
      id: schema.id,
      access_token: schema.token,
      agent_type: agent_type,
      task_id: task_id,
      delegation_chain: delegation_chain,
      scopes: schema.scopes || [],
      reason: schema.intent_description,
      expires_at: schema.expires_at,
      revoked_at: schema.revoked_at,
      organization_id: schema.organization_id,
      client_id: schema.client_id,
      created_at: schema.inserted_at
    }

    AgentToken.create(attrs)
  end

  defp task_id_to_string(nil), do: nil
  defp task_id_to_string(%TaskId{} = task_id), do: to_string(task_id)
end
