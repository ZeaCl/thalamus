defmodule Thalamus.Application.DTOs.AuthenticationRequest do
  @moduledoc """
  DTO for user authentication requests.

  SOLID Principles Applied:
  - Single Responsibility: Only carries authentication request data
  """

  @type t :: %__MODULE__{
          email: String.t(),
          password: String.t(),
          mfa_code: String.t() | nil,
          context: map()
        }

  defstruct [:email, :password, :mfa_code, :context]

  @doc """
  Creates a new authentication request.

  ## Examples

      iex> AuthenticationRequest.new(%{
      ...>   email: "user@example.com",
      ...>   password: "SecureP@ssw0rd123",
      ...>   context: %{ip_address: "192.168.1.1"}
      ...> })
      {:ok, %AuthenticationRequest{}}
  """
  def new(%{email: email, password: password} = attrs) when is_binary(email) and is_binary(password) do
    request = %__MODULE__{
      email: email,
      password: password,
      mfa_code: Map.get(attrs, :mfa_code),
      context: Map.get(attrs, :context, %{})
    }

    case validate(request) do
      :ok -> {:ok, request}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, :invalid_request}

  defp validate(%__MODULE__{email: email, password: password}) do
    cond do
      email == "" -> {:error, :email_required}
      password == "" -> {:error, :password_required}
      true -> :ok
    end
  end
end
