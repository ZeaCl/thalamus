defmodule ThalamusWeb.OAuth2.JwksController do
  @moduledoc """
  JSON Web Key Set (JWKS) endpoint controller.

  Exposes the public key used for JWT signature verification.
  Resource servers (e.g., Cerebelum) use this to validate JWT tokens.
  """
  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.JwtSigner

  @doc """
  GET /.well-known/jwks.json

  Returns the public RSA key as a JWKS document.
  Cached for 24 hours on the client side.
  """
  def show(conn, _params) do
    jwks = JwtSigner.jwks()

    conn
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> json(jwks)
  end
end
