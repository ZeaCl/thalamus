defmodule Mix.Tasks.Cli.Coverage do
  @moduledoc """
  Validates that every Thalamus API route has a CLI command. cli = api.

  Runs automatically as part of `mix compile`. Fails the build if any route
  is not mapped to a CLI command in `priv/cli_coverage.json`.

      mix cli.coverage
  """

  use Mix.Task
  @shortdoc "Verify every API route has a CLI command"

  @requirements ["app.config"]

  alias ThalamusWeb.Router

  @api_prefix "/api"

  def run(_args) do
    manifest = load_manifest()
    routes = extract_api_routes()
    manifest_routes = Map.get(manifest, "routes", %{})

    {covered, missing_in_manifest, missing_in_router} = classify(routes, manifest_routes)

    print_report(covered, missing_in_manifest, missing_in_router)

    if missing_in_manifest != [] or missing_in_router != [] do
      Mix.raise(
        "CLI coverage FAILED: #{length(missing_in_manifest)} routes missing from manifest, #{length(missing_in_router)} stale entries"
      )
    end
  end

  # ── route extraction ──────────────────────────────────────────

  defp extract_api_routes do
    Router.__routes__()
    |> Enum.map(fn route ->
      verb = route.verb |> to_string() |> String.upcase()
      "#{verb} #{route.path}"
    end)
    |> Enum.filter(fn route ->
      [_verb, path] = String.split(route, " ", parts: 2)
      String.starts_with?(path, @api_prefix)
    end)
    |> Enum.uniq()
  end

  # ── classification ───────────────────────────────────────────

  defp classify(routes, manifest_routes) do
    {covered, missing} =
      Enum.reduce(routes, {[], []}, fn route, {cov, miss} ->
        case Map.get(manifest_routes, route) do
          nil -> {cov, [route | miss]}
          cmd when is_binary(cmd) -> {[{route, cmd} | cov], miss}
        end
      end)

    extra =
      Map.keys(manifest_routes)
      |> Enum.reject(&(&1 in routes))

    {Enum.reverse(covered), Enum.reverse(missing), Enum.sort(extra)}
  end

  # ── reporting ─────────────────────────────────────────────────

  defp print_report(covered, missing, extra) do
    total = length(covered) + length(missing)

    Mix.shell().info("")
    Mix.shell().info("═══ CLI Coverage ═══")
    Mix.shell().info("Routes:  #{total} total, #{length(covered)} covered ✅")

    if missing != [] do
      Mix.shell().error("MISSING: #{length(missing)} routes not in priv/cli_coverage.json:")
      Enum.each(missing, fn route ->
        Mix.shell().error("   #{route}")
      end)
    end

    if extra != [] do
      Mix.shell().info("STALE: #{length(extra)} entries in manifest but not in router:")
      Enum.each(extra, fn route ->
        Mix.shell().info("   #{route}")
      end)
    end

    if missing == [] and extra == [] do
      Mix.shell().info("All #{total} routes mapped to CLI commands. ✅")
    end

    Mix.shell().info("")
  end

  # ── helpers ───────────────────────────────────────────────────

  defp load_manifest do
    path = Path.join(File.cwd!(), "priv/cli_coverage.json")

    unless File.exists?(path) do
      Mix.raise("CLI coverage manifest not found at #{path}")
    end

    case Jason.decode(File.read!(path)) do
      {:ok, manifest} -> manifest
      {:error, error} -> Mix.raise("Invalid CLI coverage manifest: #{inspect(error)}")
    end
  end
end
