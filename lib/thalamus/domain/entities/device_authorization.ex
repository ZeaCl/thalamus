defmodule Thalamus.Domain.Entities.DeviceAuthorization do
  @moduledoc """
  DeviceAuthorization Entity — OAuth2 Device Flow (RFC 8628).

  Represents a pending device authorization request.
  Created when a CLI initiates device flow, authorized when the user
  enters the user_code in a browser.

  SOLID Principles:
  - Single Responsibility: Encapsulates device authorization state and rules
  - Open/Closed: Extensible via protocols
  """

  @type status :: :pending | :authorized | :expired
  @type t :: %__MODULE__{
          id: String.t(),
          device_code: String.t(),
          user_code: String.t(),
          client_id: String.t(),
          scopes: [String.t()],
          user_id: String.t() | nil,
          status: status(),
          expires_at: DateTime.t(),
          last_polled_at: DateTime.t() | nil,
          interval: pos_integer(),
          authorized_at: DateTime.t() | nil,
          inserted_at: DateTime.t()
        }

  defstruct [
    :id,
    :device_code,
    :user_code,
    :client_id,
    :scopes,
    :user_id,
    :status,
    :expires_at,
    :last_polled_at,
    :interval,
    :authorized_at,
    :inserted_at
  ]

  @user_code_length 8
  @device_code_length 32
  @default_expires_in 600
  # 10 minutes
  @default_interval 5
  # 5 seconds polling interval

  @doc """
  Creates a new pending DeviceAuthorization with generated codes.

  ## Examples
      iex> DeviceAuthorization.new(client_id: "xxx", scopes: ["openid"])
      {:ok, %DeviceAuthorization{status: :pending, ...}}
  """
  def new(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    device_auth = %__MODULE__{
      id: Ecto.UUID.generate(),
      device_code: generate_device_code(),
      user_code: generate_user_code(),
      client_id: attrs[:client_id],
      scopes: attrs[:scopes] || ["openid", "profile", "email"],
      user_id: nil,
      status: :pending,
      expires_at: DateTime.add(now, @default_expires_in, :second),
      interval: @default_interval,
      last_polled_at: nil,
      authorized_at: nil,
      inserted_at: now
    }

    {:ok, device_auth}
  end

  @doc """
  Returns true if the device authorization is still pending and not expired.
  """
  def pending?(%__MODULE__{status: :pending} = da) do
    not expired?(da)
  end

  def pending?(_), do: false

  @doc """
  Returns true if the device authorization has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Returns true if the device authorization has been authorized by the user.
  """
  def authorized?(%__MODULE__{status: :authorized}), do: true
  def authorized?(_), do: false

  # ── Private helpers ─────────────────────────────────────────

  defp generate_device_code do
    :crypto.strong_rand_bytes(@device_code_length)
    |> Base.url_encode64(padding: false)
  end

  defp generate_user_code do
    # RFC 8628: user_code should be human-friendly (alphanumeric, 8 chars)
    chars = Enum.to_list(?A..?Z)
    code = for _ <- 1..@user_code_length, do: Enum.random(chars)
    code |> List.to_string() |> format_user_code()
  end

  defp format_user_code(code) do
    # Format as XXXX-XXXX for readability
    <<a::binary-size(4), b::binary-size(4)>> = code
    "#{a}-#{b}"
  end
end
