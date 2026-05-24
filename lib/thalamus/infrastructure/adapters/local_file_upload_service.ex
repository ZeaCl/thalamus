defmodule Thalamus.Infrastructure.Adapters.LocalFileUploadService do
  @moduledoc """
  Local filesystem implementation of FileUploadService port.

  Uploads files to local filesystem and serves them via static file serving.

  SOLID Principles Applied:
  - Single Responsibility: Only handles local file uploads
  - Dependency Inversion: Implements FileUploadService port
  """

  @behaviour Thalamus.Application.Ports.FileUploadService

  @upload_dir "priv/static/uploads/avatars"
  # 5MB
  @max_file_size 5 * 1024 * 1024
  @allowed_content_types ["image/jpeg", "image/jpg", "image/png", "image/gif", "image/webp"]

  @impl true
  def upload_avatar(file_data, user_id) do
    with :ok <- validate_file_size(file_data.content),
         :ok <- validate_content_type(file_data.content_type),
         {:ok, filename} <- generate_filename(user_id, file_data.filename),
         :ok <- ensure_upload_dir_exists(),
         :ok <- write_file(filename, file_data.content) do
      url = build_url(filename)
      {:ok, url}
    end
  end

  @impl true
  def delete_file(url) do
    with {:ok, filename} <- extract_filename_from_url(url),
         :ok <- delete_file_from_disk(filename) do
      :ok
    end
  end

  # Private functions

  defp validate_file_size(content) when byte_size(content) > @max_file_size do
    {:error, :file_too_large}
  end

  defp validate_file_size(_content), do: :ok

  defp validate_content_type(content_type) do
    if content_type in @allowed_content_types do
      :ok
    else
      {:error, :invalid_content_type}
    end
  end

  defp generate_filename(user_id, original_filename) do
    # Extract file extension
    extension =
      original_filename
      |> Path.extname()
      |> String.downcase()

    # Generate unique filename: user_id + timestamp + random
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    filename = "#{user_id}_#{timestamp}_#{random}#{extension}"

    {:ok, filename}
  end

  defp ensure_upload_dir_exists do
    File.mkdir_p(@upload_dir)
  end

  defp write_file(filename, content) do
    file_path = Path.join(@upload_dir, filename)

    case File.write(file_path, content) do
      :ok -> :ok
      {:error, _reason} -> {:error, :file_write_failed}
    end
  end

  defp build_url(filename) do
    # Build public URL for static file serving
    "/uploads/avatars/#{filename}"
  end

  defp extract_filename_from_url(url) do
    # Extract filename from URL like "/uploads/avatars/filename.jpg"
    case String.split(url, "/") do
      ["", "uploads", "avatars", filename] when filename != "" ->
        {:ok, filename}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp delete_file_from_disk(filename) do
    file_path = Path.join(@upload_dir, filename)

    case File.rm(file_path) do
      :ok -> :ok
      # File already deleted, consider it success
      {:error, :enoent} -> :ok
      {:error, _reason} -> {:error, :file_delete_failed}
    end
  end
end
