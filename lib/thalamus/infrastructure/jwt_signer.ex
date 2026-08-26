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

    extra =
      case Map.get(claims_map, :organization_id) || Map.get(claims_map, "organization_id") do
        nil -> extra
        org_id -> Map.put(extra, "organization_id", to_string(org_id))
      end

    extra =
      case Map.get(claims_map, :env) || Map.get(claims_map, :environment) ||
             Map.get(claims_map, "env") || Map.get(claims_map, "environment") do
        nil -> extra
        env -> Map.put(extra, "env", to_string(env))
      end

    extra =
      case Map.get(claims_map, :env_id) || Map.get(claims_map, :environment_id) ||
             Map.get(claims_map, "env_id") || Map.get(claims_map, "environment_id") do
        nil -> extra
        env_id -> Map.put(extra, "env_id", to_string(env_id))
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

  @doc """
  Verifies a signed JWT access token using the RS256 public key (JWKS).

  Returns `{:ok, claims}` when the signature is valid and the token has not
  expired. Returns `{:error, reason}` otherwise.

  Defensive fallback for legacy stateless JWTs (`client_id: thalamus_api`)
  that are not persisted in the `tokens` table. The public login endpoint
  that used to issue them has been removed.
  """
  def verify_access_token(token) when is_binary(token) do
    with {:ok, jwks} <- fetch_jwks(),
         {:ok, signer} <- build_verifier(jwks, token),
         {:ok, claims} <- Joken.verify_and_validate(%{}, token, signer),
         :ok <- validate_claims(claims) do
      {:ok, claims}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates JWT claims after signature verification.

  `Joken.verify_and_validate/3` with an empty config validates nothing beyond
  the signature, so `exp`, `nbf`, `iss` and `aud` are checked here.
  """
  def validate_claims(claims) do
    now = DateTime.utc_now() |> DateTime.to_unix()
    cfg = config()

    cond do
      not is_integer(claims["exp"]) ->
        {:error, "Missing or invalid exp claim"}

      claims["exp"] < now ->
        {:error, "Token has expired"}

      is_integer(claims["nbf"]) and claims["nbf"] > now ->
        {:error, "Token not yet valid"}

      claims["iss"] != cfg[:issuer] ->
        {:error, "Invalid issuer"}

      not is_binary(claims["aud"]) or claims["aud"] == "" ->
        {:error, "Missing audience"}

      true ->
        :ok
    end
  end

  @doc """
  Returns true when the token looks like a self-contained 3-segment JWT.
  """
  def jwt_format?(token) do
    String.match?(token, ~r/^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$/)
  end

  @doc """
  Returns true when the JWT payload belongs to a legacy stateless login
  token (`client_id: thalamus_api`).
  """
  def thalamus_api_jwt?(token) do
    with [_, payload_b64 | _] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(payload_b64, padding: false),
         {:ok, %{"client_id" => "thalamus_api"}} <- Jason.decode(json) do
      true
    else
      _ -> false
    end
  rescue
    _ -> false
  end

  # Private verification helpers

  defp fetch_jwks do
    {:ok, jwks()}
  rescue
    e ->
      require Logger
      Logger.warning("JwtSigner: JWKS fetch failed: #{Exception.message(e)}")
      {:error, "JWKS unavailable"}
  end

  defp build_verifier(jwks, token) do
    with [header_b64 | _] <- String.split(token, "."),
         {:ok, header_json} <- Base.url_decode64(header_b64, padding: false),
         {:ok, header} <- Jason.decode(header_json),
         true <- is_map(header) do
      keys = jwks[:keys] || jwks["keys"] || []

      key =
        if header["kid"],
          do: Enum.find(keys, fn k -> (k[:kid] || k["kid"]) == header["kid"] end),
          else: List.first(keys)

      case jwk_to_pem(key) do
        {:ok, pem} -> {:ok, Joken.Signer.create("RS256", %{"pem" => pem})}
        {:error, _} = error -> error
      end
    else
      _ -> {:error, "Malformed JWT header"}
    end
  end

  defp jwk_to_pem(nil), do: {:error, "No matching JWK"}

  defp jwk_to_pem(key) do
    n = key[:n] || key["n"]
    e = key[:e] || key["e"]

    with true <- is_binary(n) and is_binary(e),
         {:ok, n_bin} <- Base.url_decode64(n, padding: false),
         {:ok, e_bin} <- Base.url_decode64(e, padding: false) do
      n_int = :binary.decode_unsigned(n_bin)
      e_int = :binary.decode_unsigned(e_bin)
      pem_entry = :public_key.pem_entry_encode(:RSAPublicKey, {:RSAPublicKey, n_int, e_int})
      {:ok, :public_key.pem_encode([pem_entry])}
    else
      _ -> {:error, "Invalid JWK key"}
    end
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
    case env_key(filename) do
      nil -> read_disk_key(filename)
      env_pem when is_binary(env_pem) and env_pem != "" -> env_pem
    end
  end

  # Allow keys via environment variables (open source friendly) so the
  # private signing key never has to be committed to the repository.
  defp env_key("jwt_private_key.pem"), do: System.get_env("JWT_PRIVATE_KEY")
  defp env_key("jwt_public_key.pem"), do: System.get_env("JWT_PUBLIC_KEY")
  defp env_key(_), do: nil

  @dev_test_private_key """
  -----BEGIN PRIVATE KEY-----
  MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDLtx5QgNYgxdsK
  V5CxOIroYRo4xjJxUFJO/58z2Gsn6WevHCApQx+6xupBRWLZImiWYLxuxXOOxkU/
  BIwtKhyJuL3u7DrTdvIE4BPsJuBDADaLnpB0Ph+kwLOOWj5Ga1Smr6YTpiaNUfhu
  me/n21OveXY+ZSjrIGWdaOfZmcSNNoMW1XJN0+8cEpvklcnO2MxIw2cUhV5N33ZE
  g0az6xTZwNzJbwBiRWK6Xxg+fgTbIfh9iC5H//Odgx4DODHPoMSE0P9B2D4YniWm
  ezVd157Yf8LA3vu9M/vXbCWy+10Y/eM5yIpxqEiAceBvahIhHScUzOgGuL5/pf1Y
  foqY6oG3AgMBAAECggEARKzrcc01IqBA2wgxFaWPoo5Vpi0exTeEP/CJ7ZL4cOCN
  HSnYp8BiuncjcrSfAb9JTeS3sYosDkZGAtwYG4O2UjFvClQl8rMHHOCjprlmYf/4
  43GlliJ5TXPPNF603s2BIJ5XWQlqtrqbC0Im791vJVlHpPo6ZKWry/iZLLDbY5UR
  /Ehjccb+0SGfrHrqsb6AWPb1bdurPohLp249oQVq45kTbw9temZQAEj5I7JQUeF+
  GOg6bgXU99GoFy4U1BWdfkUuUfu0eORrdmf5FXzNuClDHl7EcrNtUUkfaib3u9y6
  vy4JdVz4gViIKsYV80hjjpwSDgAXkOf3LElQilMfmQKBgQD3gcq1XqDAAvfn4a+u
  B7LOwxAP2IfNglQB7DAD3KrbemSJE+cCq9T3HsziPnNgSe/0oErDGt9I6hqdaslC
  89K/VzFyoJCuRSXPWrwkJJ63iwcilAq0SgHTS+kobgv1eNGAAqwRG7cLprQVek3l
  +Fuj73KrWBaR6FTjjatblhEWLwKBgQDStKQ35pdmXf2L48TebBmwhT1DchbwsYxv
  7X5EGFFbURjpqwL/3TNSlwj60qHXzB+zsDVm+pThQcuJ2YKo9pPULXh4gc8CjIpw
  F0BtDUkE0L9nALN0dGiB7muF6bkFn7FlE3jFAa0DpyJbdPWaKED0fzWIbp/ijKaG
  nxJ2gIVy+QKBgQDL+liQLuN2OzwKC3JYj5mqUxIarQ4GrWEEkJ1loWfiJ7VRT2i0
  R97kpqqdznARq/2o8q2Kq8vW8LBsiYRCvGU0Mezblj6GkRA/Gn0xoEh55YdE1RMZ
  UGC+vbHzEvaiICcwQ4OBOgEaBhImHTyzyYHk0kMDuT4ok3vaaXgOq9d7GwKBgQC0
  FQe1bzM+nl4wzT5ZCvL51yaBGmVY2aY5kzUzZcVC0pEERNCPdbKDh+p41MTV9vOx
  U4yQsuHDk8Qt0OTHG9dEpIguFmOivhMjsfuyOISLxQ2RLxwxD7yyL99d2F/12oJ2
  7KlvVvtT/+hxWgj+9CBv1rkeHc4whh1dOV9CQJ3NoQKBgGtRRDAM4PCVPaH+Mlya
  CuNZIZlidXFZgNC3Cs2HVXYUJuPtVQ7AwWXTFVauYd/MNfBLF+RvxkwExKWoYFhz
  7T1WveYB4U1rb+f0e8QT4DGBh5GRmLtKPBT0MImXdG1IKJnGmZXd7KRCRK8tkM6y
  njnp8UqsFmmU73rq3VTJKRMQ
  -----END PRIVATE KEY-----
  """

  @dev_test_public_key """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy7ceUIDWIMXbCleQsTiK
  6GEaOMYycVBSTv+fM9hrJ+lnrxwgKUMfusbqQUVi2SJolmC8bsVzjsZFPwSMLSoc
  ibi97uw603byBOAT7CbgQwA2i56QdD4fpMCzjlo+RmtUpq+mE6YmjVH4bpnv59tT
  r3l2PmUo6yBlnWjn2ZnEjTaDFtVyTdPvHBKb5JXJztjMSMNnFIVeTd92RINGs+sU
  2cDcyW8AYkViul8YPn4E2yH4fYguR//znYMeAzgxz6DEhND/Qdg+GJ4lpns1Xdee
  2H/CwN77vTP712wlsvtdGP3jOciKcahIgHHgb2oSIR0nFMzoBri+f6X9WH6KmOqB
  twIDAQAB
  -----END PUBLIC KEY-----
  """

  defp read_disk_key(filename) do
    priv_path =
      case :code.priv_dir(:thalamus) do
        {:error, _} -> Path.join(File.cwd!(), "priv")
        path -> List.to_string(path)
      end

    file_path = Path.join(priv_path, filename)

    case File.read(file_path) do
      {:ok, content} ->
        content

      {:error, _} ->
        case filename do
          "jwt_private_key.pem" -> @dev_test_private_key
          "jwt_public_key.pem" -> @dev_test_public_key
          _ -> raise File.Error, reason: :enoent, action: "read file", path: file_path
        end
    end
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
