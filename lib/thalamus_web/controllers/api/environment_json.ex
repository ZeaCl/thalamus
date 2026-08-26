defmodule ThalamusWeb.API.EnvironmentJSON do
  @moduledoc """
  JSON view for rendering Environment resources.
  """
  alias Thalamus.Domain.Entities.Environment

  def index(%{environments: environments}) do
    %{data: Enum.map(environments, &data/1)}
  end

  def show(%{environment: environment}) do
    %{data: data(environment)}
  end

  def data(%Environment{} = env) do
    %{
      id: env.id,
      organization_id: env.organization_id,
      slug: env.slug,
      name: env.name,
      type: env.type,
      is_default: env.is_default,
      status: env.status,
      description: env.description,
      inserted_at: env.inserted_at,
      updated_at: env.updated_at
    }
  end
end
