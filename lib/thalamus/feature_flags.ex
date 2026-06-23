defmodule Thalamus.FeatureFlags do
  @moduledoc """
  Feature flag management for gradual rollout of new features.

  Supports:
  - Global feature flags (environment variables)
  - Per-organization feature flags (database settings)
  - Easy testing and rollback

  ## Usage

      # Check if agent tokens are enabled globally
      FeatureFlags.agent_tokens_enabled?()

      # Check if enabled for specific organization
      FeatureFlags.agent_tokens_enabled?(organization_id)

  ## Configuration

  Set in config/runtime.exs or environment:

      # Enable agent tokens globally
      ENABLE_AGENT_TOKENS=true

      # Or configure in runtime.exs
      config :thalamus, :feature_flags,
        agent_tokens: true
  """

  @doc """
  Checks if agent tokens feature is enabled.

  ## Examples

      # Check global flag
      iex> FeatureFlags.agent_tokens_enabled?()
      true

      # Check per-organization flag
      iex> FeatureFlags.agent_tokens_enabled?("org_123")
      true
  """
  @spec agent_tokens_enabled?(String.t() | nil) :: boolean()
  def agent_tokens_enabled?(organization_id \\ nil)

  def agent_tokens_enabled?(nil) do
    # Check global flag from environment or config
    global_flag_enabled?(:agent_tokens)
  end

  def agent_tokens_enabled?(organization_id) when is_binary(organization_id) do
    # First check global flag
    if global_flag_enabled?(:agent_tokens) do
      # Then check per-organization setting
      org_flag_enabled?(organization_id, :agent_tokens)
    else
      false
    end
  end

  @doc """
  Checks if a feature is enabled globally.

  Priority:
  1. Environment variable (ENABLE_<FEATURE>)
  2. Application config (:thalamus, :feature_flags, feature_name)
  3. Default (false)
  """
  @spec global_flag_enabled?(atom()) :: boolean()
  def global_flag_enabled?(feature_name) do
    env_var = feature_to_env_var(feature_name)

    case System.get_env(env_var) do
      "true" ->
        true

      "1" ->
        true

      "yes" ->
        true

      "false" ->
        false

      "0" ->
        false

      "no" ->
        false

      nil ->
        # Fall back to config
        flags = Application.get_env(:thalamus, :feature_flags, %{})
        Map.get(flags, feature_name, false)

      _ ->
        false
    end
  end

  @doc """
  Checks if a feature is enabled for a specific organization.

  Reads from organizations.settings JSONB column.
  Returns true if:
  - Organization setting is true
  - Organization setting is nil (inherits global)

  Returns false if:
  - Organization setting is explicitly false (opt-out)
  - Organization not found
  """
  @spec org_flag_enabled?(String.t(), atom()) :: boolean()
  def org_flag_enabled?(organization_id, feature_name) do
    case fetch_org_setting(organization_id, feature_name) do
      {:ok, true} -> true
      {:ok, false} -> false
      # Inherit global setting (already checked)
      {:ok, nil} -> true
      # On error, inherit global setting
      {:error, _} -> true
    end
  end

  # Private functions

  defp feature_to_env_var(:agent_tokens), do: "ENABLE_AGENT_TOKENS"

  defp feature_to_env_var(feature) do
    "ENABLE_#{feature |> Atom.to_string() |> String.upcase()}"
  end

  defp fetch_org_setting(organization_id, feature_name) do
    try do
      import Ecto.Query

      query =
        from o in "organizations",
          where: o.id == ^organization_id,
          select: fragment("settings->?->>?", "feature_flags", ^Atom.to_string(feature_name))

      case Thalamus.Repo.one(query) do
        nil -> {:ok, nil}
        "true" -> {:ok, true}
        "false" -> {:ok, false}
        _ -> {:ok, nil}
      end
    rescue
      _ -> {:error, :database_error}
    end
  end
end
