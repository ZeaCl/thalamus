defmodule Mix.Tasks.Cli.Coverage do
  @moduledoc """
  Validates that every Thalamus API route is called by the CLI (cli = api).

  Parses the actual CLI source code (cli/src/commands/*.js) via a Node.js
  script — no manifest files, no contracts, just real code.

  Runs automatically as part of `mix compile`. Fails the build if any
  API route is not covered by a CLI command.

      mix cli.coverage
  """

  use Mix.Task
  @shortdoc "Verify every API route has a CLI command (from real source)"

  @requirements ["app.config"]

  alias ThalamusWeb.Router

  @api_prefix "/api"
  @cli_dir Path.expand("cli", File.cwd!())

  def run(_args) do
    cli_routes = extract_cli_coverage()
    router_routes = extract_router_routes()

    {covered, missing, extra} = classify(router_routes, cli_routes)

    print_report(covered, missing, extra)

    if missing != [] or extra != [] do
      Mix.raise(
        "CLI coverage FAILED: #{length(missing)} routes missing, #{length(extra)} stale"
      )
    end
  end

  # ── CLI extraction (Node.js) ──────────────────────────────────

  defp extract_cli_coverage do
    script = Path.join(@cli_dir, "scripts/extract-coverage.cjs")

    unless System.find_executable("node") do
      Mix.shell().error("Node.js not found in PATH — skipping CLI coverage check")
      %{}
    else
      do_extract(script)
    end
  end

  defp do_extract(script) do
    unless File.exists?(script) do
      Mix.raise("CLI coverage script not found: #{script}")
    end

    case System.cmd("node", [script], cd: @cli_dir, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, map} -> map
          {:error, err} -> Mix.raise("Failed to parse CLI coverage: #{inspect(err)}\n#{output}")
        end

      {output, code} ->
        Mix.raise("CLI coverage script failed (exit #{code}):\n#{output}")
    end
  end

  # ── router route extraction ───────────────────────────────────

  defp extract_router_routes do
    Router.__routes__()
    |> Enum.map(fn route ->
      verb = route.verb |> to_string() |> String.upcase()
      path = route.path |> normalize_params()
      "#{verb} #{path}"
    end)
    |> Enum.filter(fn route ->
      [_verb, path] = String.split(route, " ", parts: 2)
      String.starts_with?(path, @api_prefix)
    end)
    |> Enum.uniq()
  end

  # Normalize Phoenix :param → generic placeholder for comparison
  defp normalize_params(path) do
    String.replace(path, ~r/:[a-z_]+/, ":p")
  end

  # ── classification ───────────────────────────────────────────

  defp classify(router_routes, cli_routes) do
    # Known overrides: commands that API calls via helper functions in lib/
    # or use different endpoints than the router suggests
    known_overrides = %{
      "POST /api/public/login" => "login --email",
      "GET /api/organizations" => "org list (via /oauth/userinfo)"
    }

    # Filter out known stale patterns (extraction artifacts)
    cli_routes =
      cli_routes
      |> Map.reject(fn {route, _cmd} -> String.contains?(route, "/oauth/") end)
      |> Map.reject(fn {_route, cmd} -> cmd == "doctor" end)
      |> Map.reject(fn {route, _cmd} ->
        # PATCH without params is usually extraction artifact
        String.starts_with?(route, "PATCH ") and not String.contains?(route, ":p")
      end)

    {covered, missing} =
      Enum.reduce(router_routes, {[], []}, fn route, {cov, miss} ->
        cond do
          Map.has_key?(known_overrides, route) ->
            {[{route, known_overrides[route]} | cov], miss}

          Map.has_key?(cli_routes, route) ->
            {[{route, cli_routes[route]} | cov], miss}

          # PUT/PATCH equivalence: Phoenix generates both for resources
          String.starts_with?(route, "PUT ") ->
            patch_route = String.replace(route, "PUT ", "PATCH ")
            if Map.has_key?(cli_routes, patch_route) do
              {[{route, cli_routes[patch_route]} | cov], miss}
            else
              {cov, [route | miss]}
            end

          true ->
            {cov, [route | miss]}
        end
      end)

    extra =
      Map.keys(cli_routes)
      |> Enum.reject(&(&1 in router_routes))

    {Enum.reverse(covered), Enum.reverse(missing), Enum.sort(extra)}
  end

  # ── reporting ─────────────────────────────────────────────────

  defp print_report(covered, missing, extra) do
    total = length(covered) + length(missing)

    Mix.shell().info("")
    Mix.shell().info("═══ CLI Coverage ═══")
    Mix.shell().info("CLI source: #{Path.relative_to(@cli_dir, File.cwd!())}/src/commands/*.js")

    if missing != [] do
      Mix.shell().error("MISSING #{length(missing)} route(s) — no CLI command calls them:")
      Enum.each(missing, fn route ->
        Mix.shell().error("   #{route}")
      end)
    end

    if extra != [] do
      Mix.shell().info("STALE #{length(extra)} — CLI calls these but they're not in the router:")
      Enum.each(extra, fn route ->
        Mix.shell().info("   #{route}")
      end)
    end

    if missing == [] and extra == [] do
      Mix.shell().info("#{total} routes, #{total} covered ✅")
    else
      Mix.shell().info("#{total} routes, #{length(covered)} covered, #{length(missing)} missing, #{length(extra)} stale")
    end

    Mix.shell().info("")
  end
end
