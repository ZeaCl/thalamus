defmodule Thalamus.Application.Ports.FileUploadService do
  @moduledoc """
  Port (interface) for file upload services.

  Defines the contract for uploading, deleting, and managing file uploads.

  SOLID Principles Applied:
  - Dependency Inversion: Application layer depends on this interface, not implementations
  - Interface Segregation: Focused interface for file upload operations only
  """

  @type file_data :: %{
          content: binary(),
          filename: String.t(),
          content_type: String.t()
        }

  @type upload_result :: {:ok, url :: String.t()} | {:error, reason :: atom()}
  @type delete_result :: :ok | {:error, reason :: atom()}

  @doc """
  Uploads a file and returns its public URL.

  ## Parameters
  - `file_data`: Map containing file content, filename, and content_type
  - `user_id`: User ID for organizing uploads

  ## Returns
  - `{:ok, url}`: Upload successful, returns public URL
  - `{:error, reason}`: Upload failed with reason
  """
  @callback upload_avatar(file_data(), user_id :: String.t()) :: upload_result()

  @doc """
  Deletes a file by its URL.

  ## Parameters
  - `url`: The public URL of the file to delete

  ## Returns
  - `:ok`: File deleted successfully
  - `{:error, reason}`: Delete failed with reason
  """
  @callback delete_file(url :: String.t()) :: delete_result()
end
