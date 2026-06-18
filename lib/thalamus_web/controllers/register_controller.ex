defmodule ThalamusWeb.RegisterController do
  use ThalamusWeb, :controller

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.{UserSchema, OrganizationSchema}
  import Ecto.Query
  alias URI

  def new(conn, params) do
    # Extract org_name, app_origin, and client_id from return_to query params (SDK flow)
    {org_name, app_origin, client_id} = extract_sdk_params(params)
    # Store return_to and client_id in session so it survives the POST
    return_to = params["return_to"]
    conn = if return_to, do: put_session(conn, :return_to, return_to), else: conn
    conn = if client_id, do: put_session(conn, :sdk_client_id, client_id), else: conn
    render(conn, :new, layout: false, org_name: org_name, app_origin: app_origin)
  end

  def create(conn, %{
        "user" =>
          %{
            "email" => email,
            "name" => name,
            "password" => password,
            "password_confirmation" => password_confirmation
          } = user_params
      }) do
    org_name = user_params["org_name"]
    app_origin = user_params["app_origin"]

    cond do
      email == "" or name == "" or password == "" ->
        conn
        |> put_flash(:error, "All fields are required")
        |> render(:new, layout: false)

      password != password_confirmation ->
        conn
        |> put_flash(:error, "Passwords do not match")
        |> render(:new, layout: false)

      Repo.get_by(UserSchema, email: String.downcase(email)) != nil ->
        conn
        |> put_flash(:error, "Email address already in use")
        |> render(:new, layout: false)

      true ->
        password_hash = Bcrypt.hash_pwd_salt(password)

        user_attrs = %{
          email: String.downcase(email),
          name: name,
          password_hash: password_hash,
          status: :active
        }

        changeset = UserSchema.create_changeset(user_attrs)

        case Repo.insert(changeset) do
          {:ok, user} ->
            # Generate email verification token
            verification_token = generate_verification_token(user.id)

            # Create organization if org_name provided
            org =
              if org_name not in [nil, ""] do
                case create_org_for_user(org_name, user) do
                  {:ok, org} -> org
                  {:error, _} -> nil
                end
              end

            # Register OAuth client if app_origin provided and org was created
            sdk_client_id = get_session(conn, :sdk_client_id)

            new_client_id =
              if app_origin not in [nil, ""] and org != nil do
                create_oauth_client(app_origin, org, user, sdk_client_id)
              end

            authorization_request = get_session(conn, :authorization_request)
            return_to = get_session(conn, :return_to) || conn.params["return_to"]

            # If we created a new OAuth client, inject its ID into the return_to URL
            return_to =
              if new_client_id && return_to do
                uri = URI.parse(return_to)
                query = URI.decode_query(uri.query || "")
                query = Map.put(query, "client_id", new_client_id)
                uri = %{uri | query: URI.encode_query(query)}
                URI.to_string(uri)
              else
                return_to
              end

            # Log verification link for development
            require Logger

            Logger.info(
              "Verification: http://auth.zea.localhost/verify?email=#{URI.encode_www_form(email)}&token=#{verification_token}"
            )

            conn
            |> put_flash(:info, "Welcome! Check your email to verify your account.")
            |> put_session(:user_id, user.id)
            |> delete_session(:return_to)
            |> delete_session(:authorization_request)
            |> redirect_after_login(authorization_request, return_to)

          {:error, changeset} ->
            error_message = format_changeset_errors(changeset)

            conn
            |> put_flash(:error, "Failed to create account: #{error_message}")
            |> render(:new, layout: false)
        end
    end
  end

  defp get_return_to(conn) do
    get_session(conn, :return_to) || conn.params["return_to"] ||
      System.get_env("DEFAULT_REDIRECT_URL") || "https://zea.cl/studio"
  end

  defp redirect_after_login(conn, nil, return_to) do
    target = return_to || get_return_to(conn)

    if String.starts_with?(target, "http://") or String.starts_with?(target, "https://") do
      redirect(conn, external: target)
    else
      redirect(conn, to: target)
    end
  end

  defp redirect_after_login(conn, authorization_request, _return_to)
       when is_map(authorization_request) do
    query_string = URI.encode_query(authorization_request)
    redirect(conn, to: "/oauth/authorize?" <> query_string)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{v}" end)
    |> Enum.join(", ")
  end

  defp generate_verification_token(user_id) do
    secret = Application.get_env(:thalamus, :verification_token_secret, "dev_secret")
    token_data = "#{user_id}:#{DateTime.to_unix(DateTime.utc_now())}"
    signature = :crypto.mac(:hmac, :sha256, secret, token_data)
    Base.url_encode64(token_data <> ":" <> Base.encode64(signature), padding: false)
  end

  # Extract org_name, app_origin, and client_id from return_to query params (SDK flow)
  defp extract_sdk_params(params) do
    return_to = params["return_to"] || ""
    uri = URI.parse(return_to)
    query = URI.decode_query(uri.query || "")
    {query["org_name"], query["app_origin"], query["client_id"]}
  end

  # Create organization using Ecto schema (handles binary_id correctly)
  defp create_org_for_user(org_name, user) do
    # Add random suffix to avoid unique constraint conflicts
    suffix = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    unique_name = "#{org_name}-#{suffix}"

    changeset = OrganizationSchema.create_changeset(%{name: unique_name})

    case Repo.insert(changeset) do
      {:ok, org} ->
        from(u in UserSchema, where: u.id == ^user.id)
        |> Repo.update_all(set: [organization_id: org.id])

        {:ok, %{id: org.id, name: org.name}}

      {:error, _changeset} ->
        {:error, :org_creation_failed}
    end
  end

  # Register OAuth client and return the new client_id_string
  defp create_oauth_client(app_origin, org, _user, sdk_client_id \\ nil) do
    client_id = sdk_client_id || "app_#{Ecto.UUID.generate()}"
    now = DateTime.truncate(DateTime.utc_now(), :second)
    redirect_uri = "#{app_origin}/callback"

    Repo.query!(
      "INSERT INTO oauth2_clients (id, client_id_string, name, client_type, is_active, allowed_grant_types, allowed_scopes, redirect_uris, pkce_required, token_endpoint_auth_method, access_token_lifetime, refresh_token_lifetime, authorization_code_lifetime, organization_id, inserted_at, updated_at) VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14::uuid, $15, $15)",
      [
        Ecto.UUID.dump!(Ecto.UUID.generate()),
        client_id,
        "#{org[:name]} App",
        "public",
        true,
        ["authorization_code", "refresh_token"],
        ["openid", "profile", "email"],
        [redirect_uri],
        true,
        "client_secret_post",
        3600,
        2_592_000,
        600,
        Ecto.UUID.dump!(org[:id]),
        now
      ]
    )

    client_id
  end
end
