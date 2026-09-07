defmodule Thalamus.Application.Ports.SocialAuthProvider do
  @moduledoc """
  Port behaviour for social identity providers (Google, Apple, GitHub).

  SOLID:
  - Open/Closed: New social identity providers can be added without changing use cases
  - Interface Segregation: Clean, focused interface for external OAuth2 flows
  """

  @type profile :: %{
          provider: String.t(),
          provider_uid: String.t(),
          email: String.t() | nil,
          email_verified: boolean(),
          name: String.t() | nil,
          avatar_url: String.t() | nil,
          raw: map()
        }

  @doc """
  Builds the authorization redirect URL for this provider.
  """
  @callback get_authorization_url(state :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Exchanges an authorization code for user profile data.
  """
  @callback exchange_code(code :: String.t(), opts :: keyword()) ::
              {:ok, profile()} | {:error, term()}
end
