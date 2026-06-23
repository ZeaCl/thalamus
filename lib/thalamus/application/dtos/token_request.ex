defmodule Thalamus.Application.DTOs.TokenRequest do
  @moduledoc """
  DTO for OAuth2 token requests.

  SOLID Principles Applied:
  - Single Responsibility: Only carries token request data
  """

  @type grant_type :: :authorization_code | :client_credentials | :refresh_token | :password
  @type t :: %__MODULE__{
          grant_type: grant_type(),
          client_id: String.t(),
          client_secret: String.t() | nil,
          code: String.t() | nil,
          redirect_uri: String.t() | nil,
          refresh_token: String.t() | nil,
          username: String.t() | nil,
          password: String.t() | nil,
          scope: String.t() | nil,
          code_verifier: String.t() | nil
        }

  defstruct [
    :grant_type,
    :client_id,
    :client_secret,
    :code,
    :redirect_uri,
    :refresh_token,
    :username,
    :password,
    :scope,
    :code_verifier
  ]

  @doc """
  Creates a new token request from parameters.

  ## Examples

      iex> TokenRequest.new(%{
      ...>   grant_type: "authorization_code",
      ...>   client_id: "client_123",
      ...>   code: "auth_code_456"
      ...> })
      {:ok, %TokenRequest{}}
  """
  def new(params) when is_map(params) do
    grant_type_val = params["grant_type"] || params[:grant_type]

    if is_nil(grant_type_val) or grant_type_val == "" do
      {:error, :invalid_request}
    else
      case parse_grant_type(grant_type_val) do
        {:ok, grant_type} ->
          request = %__MODULE__{
            grant_type: grant_type,
            client_id: params["client_id"] || params[:client_id],
            client_secret: params["client_secret"] || params[:client_secret],
            code: params["code"] || params[:code],
            redirect_uri: params["redirect_uri"] || params[:redirect_uri],
            refresh_token: params["refresh_token"] || params[:refresh_token],
            username: params["username"] || params[:username],
            password: params["password"] || params[:password],
            scope: params["scope"] || params[:scope],
            code_verifier: params["code_verifier"] || params[:code_verifier]
          }

          case validate(request) do
            :ok -> {:ok, request}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def new(_), do: {:error, :invalid_request}

  defp parse_grant_type("authorization_code"), do: {:ok, :authorization_code}
  defp parse_grant_type("client_credentials"), do: {:ok, :client_credentials}
  defp parse_grant_type("refresh_token"), do: {:ok, :refresh_token}
  defp parse_grant_type("password"), do: {:ok, :password}
  defp parse_grant_type(:authorization_code), do: {:ok, :authorization_code}
  defp parse_grant_type(:client_credentials), do: {:ok, :client_credentials}
  defp parse_grant_type(:refresh_token), do: {:ok, :refresh_token}
  defp parse_grant_type(:password), do: {:ok, :password}
  defp parse_grant_type(_), do: {:error, :unsupported_grant_type}

  defp validate(%__MODULE__{grant_type: :authorization_code} = req) do
    cond do
      is_nil(req.client_id) -> {:error, :client_id_required}
      is_nil(req.code) -> {:error, :code_required}
      true -> :ok
    end
  end

  defp validate(%__MODULE__{grant_type: :client_credentials} = req) do
    cond do
      is_nil(req.client_id) -> {:error, :client_id_required}
      is_nil(req.client_secret) -> {:error, :client_secret_required}
      true -> :ok
    end
  end

  defp validate(%__MODULE__{grant_type: :refresh_token} = req) do
    cond do
      is_nil(req.client_id) -> {:error, :client_id_required}
      is_nil(req.refresh_token) -> {:error, :refresh_token_required}
      true -> :ok
    end
  end

  defp validate(%__MODULE__{grant_type: :password} = req) do
    cond do
      is_nil(req.client_id) -> {:error, :client_id_required}
      true -> :ok
    end
  end
end
