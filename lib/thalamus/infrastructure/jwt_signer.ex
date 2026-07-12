defmodule Thalamus.Infrastructure.JwtSigner do
  @moduledoc """
  JWT Signer using RS256 asymmetric keys via Joken.

  Generates signed JWTs for access tokens and provides JWKS public key data.
  """

  alias Thalamus.Domain.ValueObjects.UserId
  alias Thalamus.Infrastructure.Persistence.Schemas.UserDomainRoleSchema
  alias Thalamus.Repo

  import Ecto.Query

  @doc """
  Generates a signed JWT access token.

  ## Claims
  - sub: user_id (string)
  - iss: issuer URL
  - aud: client_id (string)
  - exp: expiration timestamp
  - iat: issued at timestamp
  - jti: unique token ID
  - scope: space-separated scopes
  """
  def sign_access_token(claims_map) do
    signer = build_signer(nil)
    cfg = config()

    now = DateTime.utc_now() |> DateTime.to_unix()
    expires_in = Map.get(claims_map, :expires_in, 3600)

    base_claims = %{
      "iss" => cfg[:issuer],
      "aud" => Map.get(claims_map, :aud, "zea"),
      "iat" => now,
      "exp" => now + expires_in,
      "jti" => "jti_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))
    }

    extra = %{}

    extra =
      case Map.get(claims_map, :scope) do
        nil -> extra
        "" -> extra
        scope -> Map.put(extra, "scope", scope)
      end

    extra =
      case Map.get(claims_map, :client_id) do
        nil -> extra
        cid -> Map.put(extra, "client_id", cid)
      end

    extra =
      case Map.get(claims_map, :name) do
        nil -> extra
        name -> Map.put(extra, "name", name)
      end

    extra =
      case Map.get(claims_map, :email) do
        nil -> extra
        email -> Map.put(extra, "email", email)
      end

    extra =
      case Map.get(claims_map, :is_agent) do
        nil -> extra
        is_agent -> Map.put(extra, "is_agent", is_agent)
      end

    claims = Map.merge(base_claims, extra)

    user_id = Map.get(claims_map, :user_id)

    {:ok, token, _claims} =
      case user_id do
        %UserId{} = uid ->
          claims = Map.put(claims, "sub", UserId.to_string(uid))
          claims = add_domain_roles(claims)
          Joken.encode_and_sign(claims, signer)

        uid when is_binary(uid) and uid != "" ->
          claims = Map.put(claims, "sub", uid)
          claims = add_domain_roles(claims)
          Joken.encode_and_sign(claims, signer)

        _ ->
          Joken.encode_and_sign(claims, signer)
      end

    token
  end

  # Adds domain role claims to the JWT from the database.
  # Queries user_domain_roles for the user's scopes across all orgs.
  #
  # Always includes "domain_roles" in the JWT (empty array if no roles),
  # so downstream services can rely on its presence for authorization.
  # Also adds "authz_source" hint to prevent confusion with organization_id.
  defp add_domain_roles(claims) do
    sub = claims["sub"]

    if sub do
      raw_uid = String.replace_prefix(sub, "user_", "")
      roles = fetch_domain_roles(raw_uid)

      domain_roles =
        Enum.map(roles, fn r ->
          role_data = %{
            "org_id" => r.organization_id,
            "domain" => r.domain,
            "role" => r.role,
            "scopes" => r.scopes
          }

          if r.entity_id, do: Map.put(role_data, "entity_id", r.entity_id), else: role_data
        end)

      all_scopes =
        roles
        |> Enum.flat_map(& &1.scopes)
        |> Enum.uniq()

      claims
      |> Map.put("scopes", all_scopes)
      |> Map.put("domain_roles", domain_roles)
      |> Map.put("authz_source", "domain_roles")
    else
      claims
      |> Map.put("domain_roles", [])
      |> Map.put("authz_source", "domain_roles")
    end
  end

  defp fetch_domain_roles(user_id) do
    try do
      case Ecto.UUID.cast(user_id) do
        {:ok, uuid} ->
          Repo.all(
            from r in UserDomainRoleSchema,
              where: r.user_id == ^uuid
          )

        :error ->
          require Logger
          Logger.warning("fetch_domain_roles: invalid user_id format: #{inspect(user_id)}")
          []
      end
    rescue
      e in DBConnection.ConnectionError ->
        require Logger
        Logger.warning("fetch_domain_roles: DB connection error — #{Exception.message(e)}")
        []

      e in DBConnection.OwnershipError ->
        require Logger
        Logger.warning("fetch_domain_roles: DB ownership error — #{Exception.message(e)}")
        []
    end
  end

  @doc """
  Returns JWKS (JSON Web Key Set) data for the public key.
  Used by resource servers (e.g., Cerebelum) to validate JWT signatures.
  """
  def jwks do
    pem = read_key_file("jwt_public_key.pem")
    [rsa_key] = :public_key.pem_decode(pem)
    rsa_key_data = :public_key.pem_entry_decode(rsa_key)

    # Extract modulus (n) and exponent (e) components
    modulus = extract_rsa_component(rsa_key_data, :modulus)
    exponent = extract_rsa_component(rsa_key_data, :publicExponent)

    %{
      keys: [
        %{
          kty: "RSA",
          use: "sig",
          alg: "RS256",
          kid: key_id(),
          n: Base.url_encode64(:binary.encode_unsigned(modulus), padding: false),
          e: Base.url_encode64(:binary.encode_unsigned(exponent), padding: false)
        }
      ]
    }
  end

  defp build_signer(_config) do
    pem = read_key_file("jwt_private_key.pem")
    signer = Joken.Signer.create("RS256", %{"pem" => pem})
    signer
  end

  defp key_id do
    pem = read_key_file("jwt_public_key.pem")

    key_hash =
      :crypto.hash(:sha256, pem)
      |> Base.url_encode64(padding: false)

    String.slice(key_hash, 0, 16)
  end

  defp config do
    Application.get_env(:thalamus, :jwt, [])
  end

  defp read_key_file(filename) do
    priv_path = :code.priv_dir(:thalamus) |> List.to_string()
    File.read!(Path.join(priv_path, filename))
  end

  defp extract_rsa_component(key_data, component) do
    # Extract from Erlang public_key record
    case key_data do
      {:RSAPublicKey, modulus, exponent} ->
        case component do
          :modulus -> modulus
          :publicExponent -> exponent
        end

      {:RSAPrivateKey, _, modulus, _, _, exponent, _, _} ->
        case component do
          :modulus -> modulus
          :publicExponent -> exponent
        end

      _ ->
        <<>>
    end
  end
end
