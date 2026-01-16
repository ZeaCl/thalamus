#!/usr/bin/env elixir

# Script de validación automática del progreso del dashboard
# Uso: mix run scripts/check_progress.exs

defmodule ProgressChecker do
  @moduledoc """
  Verifica automáticamente qué tareas del ROADMAP están completadas.
  """

  def run do
    IO.puts("\n🔍 Verificando progreso del Dashboard Thalamus...\n")

    results = [
      check_milestone_1(),
      check_milestone_2(),
      check_milestone_3(),
      check_milestone_4(),
      check_milestone_5(),
      check_milestone_6(),
      check_milestone_7(),
      check_milestone_8(),
      check_milestone_9()
    ]

    print_summary(results)
  end

  # Milestone 1: UI Foundation
  defp check_milestone_1 do
    checks = [
      {"Tailwind + daisyUI configurado", file_exists?("assets/css/app.css")},
      {"Colores OKLCH en app.css", file_contains?("assets/css/app.css", "oklch")},
      {"Componentes de navegación", file_exists?("lib/thalamus_web/components/layouts.ex") &&
                                    file_contains?("lib/thalamus_web/components/layouts.ex", "sidebar_link")},
      {"Theme toggle", file_contains?("lib/thalamus_web/components/layouts.ex", "theme_toggle")},
      {"Layout con sidebar", file_exists?("lib/thalamus_web/components/layouts/app.html.heex")},
      {"Landing page", file_exists?("lib/thalamus_web/controllers/page_html/home.html.heex") &&
                       file_contains?("lib/thalamus_web/controllers/page_html/home.html.heex", "Enterprise-Grade")},
      {"Alpine.js configurado", file_contains?("lib/thalamus_web/components/layouts/app.html.heex", "alpine")},
      {"Dashboard LiveView", file_exists?("lib/thalamus_web/live/dashboard/index.ex")},
      {"Rutas configuradas", file_contains?("lib/thalamus_web/router.ex", "pipeline :dashboard")}
    ]

    {"Milestone 1: UI Foundation", checks}
  end

  # Milestone 2: Dashboard Data Connection
  defp check_milestone_2 do
    dashboard_file = "lib/thalamus_web/live/dashboard/index.ex"

    checks = [
      {"count_users/0 implementado", file_contains?(dashboard_file, "defp count_users")},
      {"count_clients/0 implementado", file_contains?(dashboard_file, "defp count_clients")},
      {"count_organizations/0 implementado", file_contains?(dashboard_file, "defp count_organizations")},
      {"count_active_tokens/0 implementado", file_contains?(dashboard_file, "defp count_active_tokens")},
      {"Actividad reciente implementada", file_contains?(dashboard_file, "load_recent_activity")}
    ]

    {"Milestone 2: Dashboard Data Connection", checks}
  end

  # Milestone 3: OAuth2 Clients CRUD
  defp check_milestone_3 do
    checks = [
      {"Clients Index LiveView", file_exists?("lib/thalamus_web/live/clients/index.ex")},
      {"Clients Form LiveView", file_exists?("lib/thalamus_web/live/clients/form.ex")},
      {"Clients Show LiveView", file_exists?("lib/thalamus_web/live/clients/show.ex")},
      {"Delete functionality", file_contains?("lib/thalamus_web/live/clients/index.ex", "handle_event(\"delete\"")},
      {"Secret rotation", file_contains?("lib/thalamus_web/live/clients/show.ex", "handle_event(\"rotate_secret\"")},
      {"Ruta clients en router", file_contains?("lib/thalamus_web/router.ex", "live \"/clients\"")},
      {"Tests de Clients", file_exists?("test/thalamus_web/live/clients/index_test.exs")}
    ]

    {"Milestone 3: OAuth2 Clients CRUD", checks}
  end

  # Milestone 4: Users Management
  defp check_milestone_4 do
    checks = [
      {"Users Index LiveView", file_exists?("lib/thalamus_web/live/users/index.ex")},
      {"Users Form Component", file_exists?("lib/thalamus_web/live/users/form_component.ex")},
      {"Users Show LiveView", file_exists?("lib/thalamus_web/live/users/show.ex")},
      {"Ruta users en router", file_contains?("lib/thalamus_web/router.ex", "/dashboard/users")},
      {"Tests de Users", file_exists?("test/thalamus_web/live/users/index_test.exs")}
    ]

    {"Milestone 4: Users Management", checks}
  end

  # Milestone 5: Organizations Management
  defp check_milestone_5 do
    checks = [
      {"Organizations Index LiveView", file_exists?("lib/thalamus_web/live/organizations/index.ex")},
      {"Organizations Form Component", file_exists?("lib/thalamus_web/live/organizations/form_component.ex")},
      {"Ruta organizations en router", file_contains?("lib/thalamus_web/router.ex", "/dashboard/organizations")},
      {"Tests de Organizations", file_exists?("test/thalamus_web/live/organizations/index_test.exs")}
    ]

    {"Milestone 5: Organizations Management", checks}
  end

  # Milestone 6: Token Management
  defp check_milestone_6 do
    checks = [
      {"Tokens Index LiveView", file_exists?("lib/thalamus_web/live/tokens/index.ex")},
      {"Ruta tokens en router", file_contains?("lib/thalamus_web/router.ex", "/dashboard/tokens")},
      {"Tests de Tokens", file_exists?("test/thalamus_web/live/tokens/index_test.exs")}
    ]

    {"Milestone 6: Token Management", checks}
  end

  # Milestone 7: Security & Auth
  defp check_milestone_7 do
    checks = [
      {"Plug RequireAuth", file_exists?("lib/thalamus_web/plugs/require_auth.ex")},
      {"Auth en pipeline :dashboard", file_contains?("lib/thalamus_web/router.ex", "RequireAuth")},
      {"Login mejorado", file_contains?("lib/thalamus_web/controllers/session_html/new.html.heex", "card")},
      {"Tests de auth", file_exists?("test/thalamus_web/plugs/require_auth_test.exs")}
    ]

    {"Milestone 7: Security & Auth", checks}
  end

  # Milestone 8: Audit & Monitoring
  defp check_milestone_8 do
    checks = [
      {"Audit Logs LiveView", file_exists?("lib/thalamus_web/live/audit_logs/index.ex")},
      {"Ruta audit logs en router", file_contains?("lib/thalamus_web/router.ex", "/dashboard/audit-logs")},
      {"Tests de Audit Logs", file_exists?("test/thalamus_web/live/audit_logs/index_test.exs")}
    ]

    {"Milestone 8: Audit & Monitoring", checks}
  end

  # Milestone 9: Polish & UX
  defp check_milestone_9 do
    checks = [
      {"Página 404 personalizada", file_exists?("lib/thalamus_web/controllers/error_html/404.html.heex")},
      {"Página 500 personalizada", file_exists?("lib/thalamus_web/controllers/error_html/500.html.heex")},
      {"Documentación de usuario", file_exists?("docs/DASHBOARD_USER_GUIDE.md")}
    ]

    {"Milestone 9: Polish & UX", checks}
  end

  # Helper functions
  defp file_exists?(path) do
    File.exists?(path)
  end

  defp file_contains?(path, content) do
    case File.read(path) do
      {:ok, file_content} -> String.contains?(file_content, content)
      {:error, _} -> false
    end
  end

  defp print_summary(results) do
    # Print each milestone and accumulate totals
    {total_tasks, completed_tasks} = Enum.reduce(results, {0, 0}, fn {milestone_name, checks}, {total_acc, completed_acc} ->
      milestone_total = length(checks)
      milestone_completed = Enum.count(checks, fn {_, passed} -> passed end)
      percentage = if milestone_total > 0, do: round(milestone_completed / milestone_total * 100), else: 0

      status_icon = if percentage == 100, do: "✅", else: if percentage > 0, do: "🔄", else: "❌"

      IO.puts("#{status_icon} #{milestone_name}")
      IO.puts("   Progress: #{milestone_completed}/#{milestone_total} (#{percentage}%)")

      Enum.each(checks, fn {task_name, passed} ->
        icon = if passed, do: "  ✓", else: "  ✗"
        IO.puts("   #{icon} #{task_name}")
      end)

      IO.puts("")

      {total_acc + milestone_total, completed_acc + milestone_completed}
    end)

    overall_percentage = if total_tasks > 0, do: round(completed_tasks / total_tasks * 100), else: 0

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("📊 RESUMEN TOTAL")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("Total de tareas: #{total_tasks}")
    IO.puts("Completadas: #{completed_tasks}")
    IO.puts("Pendientes: #{total_tasks - completed_tasks}")
    IO.puts("Progreso: #{overall_percentage}%")
    IO.puts("")

    print_progress_bar(overall_percentage)
    IO.puts("")

    if overall_percentage == 100 do
      IO.puts("🎉 ¡FELICITACIONES! Dashboard completado al 100%")
    else
      next_milestone = find_next_milestone(results)
      IO.puts("🎯 Siguiente Milestone: #{next_milestone}")
    end
  end

  defp print_progress_bar(percentage) do
    bar_length = 40
    filled = round(percentage / 100 * bar_length)
    empty = bar_length - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)
    IO.puts("Progress: [#{bar}] #{percentage}%")
  end

  defp find_next_milestone(results) do
    Enum.find_value(results, "Todos completados", fn {milestone_name, checks} ->
      milestone_completed = Enum.count(checks, fn {_, passed} -> passed end)
      milestone_total = length(checks)

      if milestone_completed < milestone_total do
        milestone_name
      else
        nil
      end
    end)
  end
end

# Ejecutar el checker
ProgressChecker.run()
