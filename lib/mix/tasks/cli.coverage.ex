defmodule Mix.Tasks.Cli.Coverage do
  @moduledoc """
  Validates that all Thalamus API routes have corresponding CLI commands
  documented in `priv/cli_coverage.json`.

  Runs automatically as part of `mix compile`. Can also be invoked directly:

      mix cli.coverage           # Warn on uncovered routes
      mix cli.coverage --strict  # Fail the build on uncovered routes

  ## Coverage manifest format

  `priv/cli_coverage.json` maps route patterns to CLI commands (or `null` if
  intentionally uncovered):

      {
        "routes": {
          "GET /api/clients": "zea thalamus clients list",
          "PATCH /api/clients/:id/trust": null
        }
      }

  Routes with `null` are considered intentionally uncovered and reported
  separately from routes that are missing from the manifest entirely.
  """

  use Mix.Task
  @shortdoc "Check CLI coverage of all API routes"

  # Routes are read from the compiled router module at runtime,
  # so this task requires compilation to have happened already.
  @requirements ["app.config"]

  alias ThalamusWeb.Router

  @api_prefix "/api"

  def run(args) do
    strict? = "--strict" in args

    manifest = load_manifest()
    routes = extract_api_routes()
    manifest_routes = Map.get(manifest, "routes", %{})

    {covered, uncovered, missing, extra} = classify(routes, manifest_routes)

    print_report(covered, uncovered, missing, extra)

    if strict? and (uncovered != [] or missing != []) do
      Mix.raise("CLI coverage check FAILED: #{length(uncovered)} uncovered, #{length(missing)} missing from manifest")
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
      # Route format: "VERB /path" — check that path starts with /api
      [_verb, path] = String.split(route, " ", parts: 2)
      String.starts_with?(path, @api_prefix)
    end)
    |> Enum.uniq()
  end

  # ── classification ───────────────────────────────────────────

  defp classify(routes, manifest_routes) do
    {covered, uncovered, missing} =
      Enum.reduce(routes, {[], [], []}, fn route, {cov, uncov, miss} ->
        case Map.get(manifest_routes, route, :not_found) do
          :not_found -> {cov, uncov, [route | miss]}
          nil -> {cov, [route | uncov], miss}
          cmd when is_binary(cmd) -> {[{route, cmd} | cov], uncov, miss}
        end
      end)

    extra =
      Map.keys(manifest_routes)
      |> Enum.reject(&(&1 in routes))

    {Enum.reverse(covered), Enum.reverse(uncovered), Enum.reverse(missing), Enum.sort(extra)}
  end

  # ── reporting ─────────────────────────────────────────────────

  defp print_report(covered, uncovered, missing, extra) do
    total = length(covered) + length(uncovered) + length(missing)

    Mix.shell().info("")
    Mix.shell().info("═══ CLI Coverage Report ═══")
    Mix.shell().info("Total API routes: #{total}")
    Mix.shell().info("Covered:    #{length(covered)} ✅")
    Mix.shell().info("Uncovered:  #{length(uncovered)} 🟡 (intentionally, marked null)")
    Mix.shell().info("Missing:    #{length(missing)} 🔴 (not in manifest at all)")
    Mix.shell().info("Extra:      #{length(extra)} ⚠️  (in manifest but not in router)")
    Mix.shell().info("")

    unless Enum.empty?(missing) do
      Mix.shell().error("❌ Routes MISSING from priv/cli_coverage.json:")
      Enum.each(missing, fn route ->
        Mix.shell().error("   #{route}")
      end)
      Mix.shell().info("")
    end

    if strict?() do
      unless Enum.empty?(uncovered) do
        Mix.shell().info("🟡 Intentionally uncovered (null in manifest):")
        Enum.each(uncovered, fn route ->
          Mix.shell().info("   #{route}")
        end)
        Mix.shell().info("")
      end
    end

    unless Enum.empty?(extra) do
      Mix.shell().info("⚠️  Routes in manifest but NOT in router (stale?):")
      Enum.each(extra, fn route ->
        Mix.shell().info("   #{route}")
      end)
      Mix.shell().info("")
    end
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

  defp strict? do
    Application.get_env(:thalamus, :cli_coverage_strict, false)
  end
end
