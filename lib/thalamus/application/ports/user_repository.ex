defmodule Thalamus.Application.Ports.UserRepository do
  @moduledoc """
  Repository port (interface) for User entity persistence.

  SOLID Principles Applied:
  - Interface Segregation: Focused interface for user data access
  - Dependency Inversion: Application layer depends on this abstraction
  """

  alias Thalamus.Domain.Entities.User
  alias Thalamus.Domain.ValueObjects.{UserId, Email}

  @doc """
  Finds a user by their ID.

  ## Examples

      iex> UserRepository.find_by_id(user_id)
      {:ok, %User{}}

      iex> UserRepository.find_by_id(non_existent_id)
      {:error, :not_found}
  """
  @callback find_by_id(UserId.t()) :: {:ok, User.t()} | {:error, :not_found}

  @doc """
  Finds a user by their email address.

  ## Examples

      iex> UserRepository.find_by_email(email)
      {:ok, %User{}}

      iex> UserRepository.find_by_email(non_existent_email)
      {:error, :not_found}
  """
  @callback find_by_email(Email.t()) :: {:ok, User.t()} | {:error, :not_found}

  @doc """
  Saves a new user or updates an existing one.

  ## Examples

      iex> UserRepository.save(user)
      {:ok, %User{}}

      iex> UserRepository.save(invalid_user)
      {:error, :validation_failed}
  """
  @callback save(User.t()) :: {:ok, User.t()} | {:error, term()}

  @doc """
  Updates the last login timestamp for a user.

  ## Examples

      iex> UserRepository.update_last_login(user_id, DateTime.utc_now())
      :ok
  """
  @callback update_last_login(UserId.t(), DateTime.t()) :: :ok | {:error, term()}

  @doc """
  Deletes a user (soft or hard delete depending on implementation).

  ## Examples

      iex> UserRepository.delete(user_id)
      :ok
  """
  @callback delete(UserId.t()) :: :ok | {:error, term()}

  @doc """
  Lists users with pagination.

  ## Examples

      iex> UserRepository.list(limit: 10, offset: 0)
      {:ok, [%User{}, ...]}
  """
  @callback list(keyword()) :: {:ok, [User.t()]} | {:error, term()}

  @doc """
  Counts total number of users.

  ## Examples

      iex> UserRepository.count()
      {:ok, 1234}
  """
  @callback count() :: {:ok, non_neg_integer()} | {:error, term()}
end
