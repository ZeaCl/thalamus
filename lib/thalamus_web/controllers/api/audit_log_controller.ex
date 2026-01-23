defmodule ThalamusWeb.API.AuditLogController do
  @moduledoc """
  REST API controller for Audit Log compliance exports.

  Provides GDPR-compliant audit log exports in CSV and JSON formats
  with comprehensive filtering capabilities.

  SOLID Principles:
  - Single Responsibility: Only handles audit log export operations
  - Open/Closed: Extensible for new export formats
  """

  use ThalamusWeb, :controller

  import Ecto.Query
  alias Thalamus.Repo
  alias Thalamus.Infrastructure.Persistence.Schemas.AuditLogSchema

  @doc """
  Exports audit logs in CSV or JSON format with filtering.

  GET /api/audit-logs/export?format=csv&from=2024-01-01&to=2024-12-31&event_type=user_created

  Query Parameters:
  - format: "csv" or "json" (default: "csv")
  - from: Start date (ISO8601 format)
  - to: End date (ISO8601 format)
  - event_type: Filter by event type
  - user_id: Filter by user
  - organization_id: Filter by organization
  - limit: Max records (default: 10000, max: 50000)
  """
  def export(conn, params) do
    organization_id = get_organization_id(conn)
    format = Map.get(params, "format", "csv")

    with {:ok, org_id} <- validate_organization_id(organization_id),
         :ok <- validate_format(format),
         {:ok, filters} <- parse_filters(params, org_id),
         {:ok, audit_logs} <- fetch_audit_logs(filters) do
      case format do
        "csv" -> export_csv(conn, audit_logs)
        "json" -> export_json(conn, audit_logs)
      end
    else
      {:error, :invalid_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_format", message: "Format must be 'csv' or 'json'"})

      {:error, :invalid_date_range} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_date_range", message: "Invalid date format. Use ISO8601 (e.g., 2024-01-01T00:00:00Z)"})

      {:error, :date_range_too_large} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "date_range_too_large", message: "Date range cannot exceed 1 year"})

      {:error, :limit_exceeded} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "limit_exceeded", message: "Limit cannot exceed 50000 records"})

      {:error, :missing_organization} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", message: "Organization context required"})
    end
  end

  # Private functions

  defp validate_organization_id(nil), do: {:error, :missing_organization}
  defp validate_organization_id(org_id) when is_binary(org_id), do: {:ok, org_id}

  defp validate_format(format) when format in ["csv", "json"], do: :ok
  defp validate_format(_), do: {:error, :invalid_format}

  defp parse_filters(params, organization_id) do
    limit = parse_limit(params)

    with {:ok, from_date} <- parse_date(params, "from"),
         {:ok, to_date} <- parse_date(params, "to"),
         :ok <- validate_date_range(from_date, to_date),
         :ok <- validate_limit(limit) do
      filters = %{
        organization_id: organization_id,
        from: from_date,
        to: to_date,
        event_type: params["event_type"],
        user_id: params["user_id"],
        limit: limit
      }

      {:ok, filters}
    end
  end

  defp parse_date(params, key) do
    case Map.get(params, key) do
      nil ->
        # Default dates if not provided
        default_date(key)

      date_string ->
        case DateTime.from_iso8601(date_string) do
          {:ok, datetime, _offset} -> {:ok, datetime}
          {:error, _} -> {:error, :invalid_date_range}
        end
    end
  end

  defp default_date("from") do
    # Default to 90 days ago
    {:ok, DateTime.utc_now() |> DateTime.add(-90, :day) |> DateTime.truncate(:second)}
  end

  defp default_date("to") do
    # Default to now
    {:ok, DateTime.utc_now() |> DateTime.truncate(:second)}
  end

  defp validate_date_range(from_date, to_date) do
    diff_days = DateTime.diff(to_date, from_date, :day)

    cond do
      diff_days < 0 -> {:error, :invalid_date_range}
      diff_days > 365 -> {:error, :date_range_too_large}
      true -> :ok
    end
  end

  defp parse_limit(params) do
    case Map.get(params, "limit") do
      nil -> 10_000
      limit_str -> String.to_integer(limit_str)
    end
  rescue
    _ -> 10_000
  end

  defp validate_limit(limit) when limit > 0 and limit <= 50_000, do: :ok
  defp validate_limit(_), do: {:error, :limit_exceeded}

  defp fetch_audit_logs(filters) do
    query =
      from a in AuditLogSchema,
        where: a.organization_id == ^filters.organization_id,
        where: a.inserted_at >= ^filters.from,
        where: a.inserted_at <= ^filters.to,
        order_by: [desc: a.inserted_at],
        limit: ^filters.limit,
        preload: [:user, :organization, :client]

    query =
      if filters.event_type do
        from a in query, where: a.event_type == ^filters.event_type
      else
        query
      end

    query =
      if filters.user_id do
        from a in query, where: a.user_id == ^filters.user_id
      else
        query
      end

    audit_logs = Repo.all(query)
    {:ok, audit_logs}
  end

  defp export_csv(conn, audit_logs) do
    csv_content = generate_csv(audit_logs)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"audit_logs_#{timestamp()}.csv\"")
    |> send_resp(200, csv_content)
  end

  defp export_json(conn, audit_logs) do
    json_data = Enum.map(audit_logs, &audit_log_to_map/1)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"audit_logs_#{timestamp()}.json\"")
    |> json(%{
      exported_at: DateTime.utc_now(),
      total_records: length(json_data),
      audit_logs: json_data
    })
  end

  defp generate_csv(audit_logs) do
    headers = [
      "ID",
      "Timestamp",
      "Event Type",
      "User ID",
      "User Email",
      "Organization ID",
      "Organization Name",
      "Client ID",
      "IP Address",
      "User Agent",
      "Request ID",
      "Metadata"
    ]

    rows =
      Enum.map(audit_logs, fn log ->
        [
          log.id,
          DateTime.to_iso8601(log.inserted_at),
          log.event_type,
          log.user_id || "",
          get_user_email(log.user),
          log.organization_id || "",
          get_organization_name(log.organization),
          log.client_id || "",
          log.ip_address || "",
          log.user_agent || "",
          log.request_id || "",
          Jason.encode!(log.metadata)
        ]
      end)

    [headers | rows]
    |> CSV.encode()
    |> Enum.to_list()
    |> IO.iodata_to_binary()
  end

  defp audit_log_to_map(log) do
    %{
      id: log.id,
      timestamp: DateTime.to_iso8601(log.inserted_at),
      event_type: log.event_type,
      user: user_info(log.user),
      organization: organization_info(log.organization),
      client: client_info(log.client),
      ip_address: log.ip_address,
      user_agent: log.user_agent,
      request_id: log.request_id,
      metadata: log.metadata,
      environment: log.environment,
      node: log.node
    }
  end

  defp user_info(nil), do: nil

  defp user_info(user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name
    }
  end

  defp organization_info(nil), do: nil

  defp organization_info(org) do
    %{
      id: org.id,
      name: org.name
    }
  end

  defp client_info(nil), do: nil

  defp client_info(client) do
    %{
      id: client.id,
      name: client.name
    }
  end

  defp get_user_email(nil), do: ""
  defp get_user_email(user), do: user.email || ""

  defp get_organization_name(nil), do: ""
  defp get_organization_name(org), do: org.name || ""

  defp get_organization_id(conn) do
    case conn.assigns do
      %{current_user: %{organization_id: org_id}} -> org_id
      %{organization_id: org_id} -> org_id
      _ -> nil
    end
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace(":", "-")
    |> String.replace(".", "-")
  end
end
