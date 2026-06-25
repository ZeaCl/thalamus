defmodule Thalamus.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix.
  """
  @app :thalamus

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo_module ->
        Ecto.Migrator.run(repo_module, :up, all: true)

        seed_script = Application.app_dir(@app, "priv/repo/seeds.exs")
        if File.exists?(seed_script) do
          IO.puts("Running seed script...")
          Code.eval_file(seed_script)
        end
      end)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
