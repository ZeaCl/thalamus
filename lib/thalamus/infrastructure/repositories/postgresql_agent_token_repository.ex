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

  require Logger
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
          nil ->
            # Token has ID but doesn't exist in DB - insert with explicit ID
            TokenSchema.create_changeset(attrs)

          existing_schema ->
            # Cast attributes onto existing schema for update
            import Ecto.Changeset

            existing_schema
            |> cast(attrs, [
              :token,
              :type,
              :scopes,
              :expires_at,
              :revoked,
              :revoked_at,
              :agent_type,
              :delegation_chain,
              :task_id,
              :intent_description,
              :organization_id,
              :client_id
            ])
            |> validate_required([:token, :type, :client_id, :expires_at])
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
    base_agent_tokens_query()
    |> where([t], t.id == ^id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> to_domain(schema)
    end
  end

  @impl true
  def find_by_access_token(access_token) when is_binary(access_token) do
    base_agent_tokens_query()
    |> where([t], t.token == ^access_token)
    |> where([t], t.revoked == false)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      schema -> to_domain(schema)
    end
  end

  @impl true
  def revoke(access_token) when is_binary(access_token) do
    base_agent_tokens_query()
    |> where([t], t.token == ^access_token)
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
    # Convert UUID string to binary for PostgreSQL comparison
    case Ecto.UUID.dump(user_id) do
      {:ok, user_id_binary} ->
        # Wrap in transaction for atomicity
        Repo.transaction(fn ->
          now = DateTime.utc_now()

          # Revoke all tokens where this user_id appears in the delegation chain
          # Using fragment with ANY for better PostgreSQL performance
          {count, _} =
            base_agent_tokens_query()
            |> where([t], t.revoked == false)
            |> where([t], fragment("? = ANY(?)", ^user_id_binary, t.delegation_chain))
            |> Repo.update_all(set: [revoked: true, revoked_at: now])

          count
        end)
        |> case do
          {:ok, count} -> {:ok, count}
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:error, :invalid_user_id}
    end
  end

  @impl true
  def find_by_organization(organization_id, opts \\ []) when is_binary(organization_id) do
    query =
      base_agent_tokens_query()
      |> where([t], t.organization_id == ^organization_id)
      |> apply_agent_type_filter(opts)
      |> apply_active_filter(opts)
      |> apply_pagination(opts)
      |> order_by([t], desc: t.inserted_at)

    schemas = Repo.all(query)
    tokens = convert_schemas_to_tokens(schemas, organization_id)

    {:ok, tokens}
  end

  @impl true
  def cleanup_expired do
    now = DateTime.utc_now()

    {count, _} =
      base_agent_tokens_query()
      |> where([t], t.expires_at < ^now)
      |> Repo.delete_all()

    {:ok, count}
  end

  # --- Private Helper Functions ---

  # Base query for agent tokens (filters out non-agent tokens)
  defp base_agent_tokens_query do
    from(t in TokenSchema, where: not is_nil(t.agent_type))
  end

  # Apply agent_type filter to query
  defp apply_agent_type_filter(query, opts) do
    case Keyword.get(opts, :agent_type) do
      nil -> query
      agent_type -> where(query, [t], t.agent_type == ^to_string(agent_type))
    end
  end

  # Apply active_only filter to query
  defp apply_active_filter(query, opts) do
    if Keyword.get(opts, :active_only, false) do
      now = DateTime.utc_now()

      query
      |> where([t], t.revoked == false)
      |> where([t], t.expires_at > ^now)
    else
      query
    end
  end

  # Apply pagination (limit and offset) to query
  defp apply_pagination(query, opts) do
    query
    |> apply_limit(opts)
    |> apply_offset(opts)
  end

  defp apply_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> limit(query, ^limit)
    end
  end

  defp apply_offset(query, opts) do
    case Keyword.get(opts, :offset) do
      nil -> query
      offset -> offset(query, ^offset)
    end
  end

  # Convert list of schemas to domain tokens with error handling
  defp convert_schemas_to_tokens(schemas, organization_id) do
    {tokens, errors} =
      Enum.reduce(schemas, {[], []}, fn schema, {tokens_acc, errors_acc} ->
        try do
          {:ok, token} = to_domain(schema)
          {[token | tokens_acc], errors_acc}
        rescue
          error ->
            log_conversion_error(schema, organization_id, error)
            {tokens_acc, [{schema.id, error} | errors_acc]}
        end
      end)

    log_conversion_errors_summary(errors, schemas, organization_id)
    Enum.reverse(tokens)
  end

  defp log_conversion_error(schema, organization_id, error) do
    Logger.warning(
      "Failed to convert TokenSchema to AgentToken domain entity",
      token_id: schema.id,
      organization_id: organization_id,
      error: inspect(error)
    )
  end

  defp log_conversion_errors_summary(errors, schemas, organization_id) do
    unless Enum.empty?(errors) do
      Logger.error(
        "Data integrity issue: #{length(errors)} agent tokens failed domain conversion",
        organization_id: organization_id,
        failed_count: length(errors),
        total_count: length(schemas),
        failed_token_ids: Enum.map(errors, fn {id, _} -> id end)
      )
    end
  end

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
  # Uses from_trusted_attrs since data from DB is already validated
  defp to_domain(%TokenSchema{} = schema) do
    {:ok, agent_type} = AgentType.new(schema.agent_type)

    attrs = %{
      id: schema.id,
      access_token: schema.token,
      agent_type: agent_type,
      task_id: reconstruct_task_id(schema.task_id),
      delegation_chain: reconstruct_delegation_chain(schema.delegation_chain),
      scopes: schema.scopes || [],
      reason: schema.intent_description,
      expires_at: schema.expires_at,
      revoked_at: schema.revoked_at,
      organization_id: schema.organization_id,
      client_id: schema.client_id,
      created_at: schema.inserted_at
    }

    AgentToken.from_trusted_attrs(attrs)
  end

  # Reconstruct TaskId value object from schema field
  defp reconstruct_task_id(nil), do: nil

  defp reconstruct_task_id(task_id_string) do
    case TaskId.new(task_id_string) do
      {:ok, task_id} -> task_id
      _ -> nil
    end
  end

  # Reconstruct DelegationChain value object from schema field
  defp reconstruct_delegation_chain(nil), do: get_root_chain()
  defp reconstruct_delegation_chain([]), do: get_root_chain()

  defp reconstruct_delegation_chain(chain_uuids) when is_list(chain_uuids) do
    case DelegationChain.new(chain_uuids) do
      {:ok, chain} -> chain
      _ -> get_root_chain()
    end
  end

  defp get_root_chain do
    {:ok, chain} = DelegationChain.root()
    chain
  end

  defp task_id_to_string(nil), do: nil
  defp task_id_to_string(%TaskId{} = task_id), do: to_string(task_id)
end
