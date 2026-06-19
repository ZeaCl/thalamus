defmodule ThalamusWeb.RegistrationController do
  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Infrastructure.Repositories.PostgreSQLOrganizationRepository

  alias Thalamus.Domain.Entities.{User, Organization}
  alias Thalamus.Domain.ValueObjects.{UserId, Email, OrganizationId}

  def new(conn, _params) do
    render(conn, :new, layout: false)
  end

  def create(conn, %{"registration" => registration_params}) do
    email = registration_params["email"]
    password = registration_params["password"]
    name = registration_params["name"]

    # Validate inputs
    with {:ok, email_string} <- validate_required(email, "email"),
         {:ok, password_string} <- validate_required(password, "password"),
         {:ok, name_string} <- validate_required(name, "name"),
         {:ok, email_vo} <- Email.new(email_string),
         {:ok, nil} <- check_email_available(email_vo),
         # Create personal organization first
         {:ok, organization} <- create_personal_organization(name_string, email_string),
         {:ok, saved_org} <- PostgreSQLOrganizationRepository.save(organization),
         # Create user (domain entity doesn't have organization_id)
         {:ok, user} <- create_user(email_string, password_string, name_string),
         {:ok, saved_user} <- PostgreSQLUserRepository.save(user),
         # Associate user with organization at schema level
         :ok <- update_user_organization(saved_user.id, saved_org.id),
         # Auto-verify user (skip email verification for MVP)
         {:ok, verified_user} <- User.verify_email(saved_user),
         {:ok, final_user} <- PostgreSQLUserRepository.save(verified_user) do
      # Extract UUID without "user_" prefix for session
      user_id_string = UserId.to_string(final_user.id)
      uuid_only = String.replace_prefix(user_id_string, "user_", "")

      # Log the user in immediately
      conn
      |> put_flash(:info, "Welcome to Thalamus! Your account has been created.")
      |> put_session(:user_id, uuid_only)
      |> redirect(to: ~p"/")
    else
      {:error, :missing_parameter, param} ->
        conn
        |> put_flash(:error, "Please provide #{param}")
        |> render(:new, layout: false)

      {:error, :email_already_exists} ->
        conn
        |> put_flash(:error, "Email address already registered. Please sign in instead.")
        |> render(:new, layout: false)

      {:error, :invalid_email} ->
        conn
        |> put_flash(:error, "Please provide a valid email address")
        |> render(:new, layout: false)

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_flash(:error, "Invalid input: #{to_string(reason)}")
        |> render(:new, layout: false)

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = parse_changeset_errors(changeset)

        conn
        |> put_flash(:error, format_errors(errors))
        |> render(:new, layout: false)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Unable to create account: #{inspect(reason)}")
        |> render(:new, layout: false)
    end
  end

  def success(conn, _params) do
    render(conn, :success, layout: false)
  end

  # Private helper functions

  defp validate_required(nil, param), do: {:error, :missing_parameter, param}
  defp validate_required("", param), do: {:error, :missing_parameter, param}
  defp validate_required(value, _param), do: {:ok, value}

  defp check_email_available(email) do
    case PostgreSQLUserRepository.find_by_email(email) do
      {:ok, _user} ->
        {:error, :email_already_exists}

      {:error, :not_found} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_personal_organization(name, email_string) do
    org_name = "#{name}'s Organization"

    # Use Organization.new/3 which creates the organization with email
    Organization.new(org_name, email_string, :free)
  end

  defp create_user(email_string, password, name) do
    with {:ok, user_id} <- UserId.generate(),
         {:ok, email} <- Email.new(email_string),
         {:ok, password_hash} <-
           Thalamus.Domain.ValueObjects.PasswordHash.from_password(password) do
      User.new(%{
        id: user_id,
        email: email,
        name: name,
        password_hash: password_hash
      })
    end
  end

  defp update_user_organization(user_id, organization_id) do
    alias Thalamus.Infrastructure.Persistence.Schemas.UserSchema

    # Extract UUIDs from domain value objects
    user_uuid = UserId.to_string(user_id) |> String.replace_prefix("user_", "")
    org_uuid = OrganizationId.to_string(organization_id) |> String.replace_prefix("org_", "")

    case Thalamus.Repo.get(UserSchema, user_uuid) do
      nil ->
        {:error, :user_not_found}

      user_schema ->
        user_schema
        |> Ecto.Changeset.change(%{organization_id: org_uuid})
        |> Thalamus.Repo.update()
        |> case do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp parse_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {field, messages} ->
      "#{field}: #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
