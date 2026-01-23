defmodule ThalamusWeb.API.AvatarController do
  @moduledoc """
  Avatar Management API Controller.

  Handles user avatar upload and deletion.

  SOLID Principles Applied:
  - Single Responsibility: Only handles avatar HTTP requests
  - Dependency Inversion: Depends on FileUploadService port
  """

  use ThalamusWeb, :controller

  alias Thalamus.Infrastructure.Repositories.PostgreSQLUserRepository
  alias Thalamus.Infrastructure.Adapters.LocalFileUploadService
  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.UserId

  @max_file_size 5 * 1024 * 1024  # 5MB
  @allowed_content_types ["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"]

  @doc """
  POST /api/avatar

  Upload user avatar (requires authentication).

  ## Request
  - Multipart form data with "avatar" field containing image file
  - Requires Bearer token in Authorization header

  ## Response
  - 200 OK: Avatar uploaded successfully
  - 400 Bad Request: Invalid file or validation error
  - 401 Unauthorized: Not authenticated
  - 413 Payload Too Large: File exceeds size limit
  """
  def upload(conn, params) do
    with {:ok, user_id} <- get_authenticated_user_id(conn),
         {:ok, upload} <- get_upload_file(params),
         :ok <- validate_file_size(upload),
         :ok <- validate_content_type(upload),
         {:ok, file_content} <- read_file_content(upload),
         file_data <- build_file_data(upload, file_content),
         {:ok, avatar_url} <- LocalFileUploadService.upload_avatar(file_data, UserId.to_string(user_id)),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, old_avatar_url} <- get_old_avatar_url(user),
         {:ok, updated_user} <- User.set_avatar(user, avatar_url),
         {:ok, saved_user} <- PostgreSQLUserRepository.save(updated_user),
         :ok <- delete_old_avatar_if_exists(old_avatar_url) do
      conn
      |> put_status(:ok)
      |> json(%{
        data: %{
          avatar_url: avatar_url,
          user_id: UserId.to_string(saved_user.id)
        },
        message: "Avatar uploaded successfully"
      })
    else
      {:error, :not_authenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :no_file_uploaded} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "No file uploaded. Please provide an 'avatar' field in form data."})

      {:error, :file_too_large} ->
        conn
        |> put_status(:request_entity_too_large)
        |> json(%{error: "File too large. Maximum size is 5MB."})

      {:error, :invalid_content_type} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed."})

      {:error, :file_read_failed} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to read uploaded file"})

      {:error, :file_write_failed} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to save file"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Avatar upload failed", details: inspect(reason)})
    end
  end

  @doc """
  DELETE /api/avatar

  Delete user avatar (requires authentication).

  ## Response
  - 200 OK: Avatar deleted successfully
  - 401 Unauthorized: Not authenticated
  - 404 Not Found: User not found or no avatar set
  """
  def delete(conn, _params) do
    with {:ok, user_id} <- get_authenticated_user_id(conn),
         {:ok, user} <- PostgreSQLUserRepository.find_by_id(user_id),
         {:ok, avatar_url} <- get_current_avatar_url(user),
         {:ok, updated_user} <- User.remove_avatar(user),
         {:ok, _saved_user} <- PostgreSQLUserRepository.save(updated_user),
         :ok <- LocalFileUploadService.delete_file(avatar_url) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Avatar deleted successfully"
      })
    else
      {:error, :not_authenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :no_avatar} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No avatar set"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Avatar deletion failed", details: inspect(reason)})
    end
  end

  # Private helper functions

  defp get_authenticated_user_id(conn) do
    case conn.assigns[:current_user_id] do
      nil ->
        {:error, :not_authenticated}

      user_id when is_binary(user_id) ->
        UserId.from_string(user_id)

      user_id ->
        {:ok, user_id}
    end
  end

  defp get_upload_file(params) do
    case params["avatar"] do
      %Plug.Upload{} = upload ->
        {:ok, upload}

      _ ->
        {:error, :no_file_uploaded}
    end
  end

  defp validate_file_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when size <= @max_file_size ->
        :ok

      {:ok, %File.Stat{}} ->
        {:error, :file_too_large}

      {:error, _} ->
        {:error, :file_read_failed}
    end
  end

  defp validate_content_type(%Plug.Upload{content_type: content_type}) do
    if content_type in @allowed_content_types do
      :ok
    else
      {:error, :invalid_content_type}
    end
  end

  defp read_file_content(%Plug.Upload{path: path}) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, _} -> {:error, :file_read_failed}
    end
  end

  defp build_file_data(%Plug.Upload{filename: filename, content_type: content_type}, content) do
    %{
      content: content,
      filename: filename,
      content_type: content_type
    }
  end

  defp get_old_avatar_url(%User{avatar_url: nil}), do: {:ok, nil}
  defp get_old_avatar_url(%User{avatar_url: url}), do: {:ok, url}

  defp get_current_avatar_url(%User{avatar_url: nil}), do: {:error, :no_avatar}
  defp get_current_avatar_url(%User{avatar_url: url}), do: {:ok, url}

  defp delete_old_avatar_if_exists(nil), do: :ok

  defp delete_old_avatar_if_exists(url) do
    # Best effort deletion - don't fail upload if old file deletion fails
    case LocalFileUploadService.delete_file(url) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end
end
