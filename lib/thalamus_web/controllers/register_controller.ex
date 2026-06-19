defmodule ThalamusWeb.RegisterController do
  use ThalamusWeb, :controller

  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

  def new(conn, _params) do
    render(conn, :new, layout: false)
  end

  def create(conn, %{
        "user" => %{
          "email" => email,
          "name" => name,
          "password" => password,
          "password_confirmation" => password_confirmation
        }
      }) do
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

        user_params = %{
          email: String.downcase(email),
          name: name,
          password_hash: password_hash,
          status: :active,
          verified_at: DateTime.truncate(DateTime.utc_now(), :second)
        }

        changeset = UserSchema.create_changeset(user_params)

        case Repo.insert(changeset) do
          {:ok, user} ->
            authorization_request = get_session(conn, :authorization_request)

            conn
            |> put_flash(:info, "Welcome! Your account was successfully created.")
            |> put_session(:user_id, user.id)
            |> delete_session(:return_to)
            |> delete_session(:authorization_request)
            |> redirect_after_login(authorization_request)

          {:error, changeset} ->
            error_message = format_changeset_errors(changeset)

            conn
            |> put_flash(:error, "Failed to create account: #{error_message}")
            |> render(:new, layout: false)
        end
    end
  end

  defp get_return_to(conn) do
    get_session(conn, :return_to) || conn.params["return_to"] || ~p"/"
  end

  defp redirect_after_login(conn, nil) do
    redirect(conn, to: get_return_to(conn))
  end

  defp redirect_after_login(conn, authorization_request) when is_map(authorization_request) do
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
end
