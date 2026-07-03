# Audit Logs API

Export compliance audit logs in CSV or JSON format. Filterable by date range, organization, and event type.

---

## Endpoint

```
GET /api/audit-logs/export
Authorization: Bearer eyJhbGciOi...
```

**Pipeline:** `authenticated_api` — JWT Bearer, 5000 req/min per user.

---

## Request

```bash
curl "http://localhost:4000/api/audit-logs/export?organization_id=org_abc123&from=2026-01-01&to=2026-06-30&format=csv&limit=10000" \
  -H "Authorization: Bearer eyJhbGciOi..."
```

**Query Parameters:**

| Parameter | Required | Description |
|---|---|---|
| `organization_id` | ✅ | Organization UUID |
| `from` | ❌ | Start date (ISO 8601). Default: 30 days ago |
| `to` | ❌ | End date (ISO 8601). Default: now |
| `format` | ❌ | `csv` or `json`. Default: `csv` |
| `limit` | ❌ | Max records. Default: 1000, Max: 50000 |

---

## CSV Response

```csv
timestamp,event_type,actor_type,actor_id,resource_type,resource_id,organization_id,metadata
2026-06-15T10:30:00Z,user.login,user,user_abc123,session,sess_xyz,org_abc123,"{""ip"":""192.168.1.1""}"
2026-06-15T10:35:00Z,agent_token.created,oauth2_client,client_abc,agent_token,agt_xyz,org_abc123,"{""agent_type"":""autonomous"",""task_description"":""Analyze data""}"
2026-06-15T10:40:00Z,step_authorization.granted,agent_token,agt_xyz,workflow_step,send_email,org_abc123,"{""step_name"":""send_email"",""required_scopes"":[""email:send""]}"
```

**CSV Headers:**

| Column | Description |
|---|---|
| `timestamp` | ISO 8601 timestamp |
| `event_type` | Event category |
| `actor_type` | Who performed the action (`user`, `oauth2_client`, `agent_token`) |
| `actor_id` | Actor UUID |
| `resource_type` | What was acted upon |
| `resource_id` | Resource UUID |
| `organization_id` | Organization UUID |
| `metadata` | JSON blob with event-specific details |

---

## JSON Response

```bash
curl "...&format=json" -H "Authorization: Bearer eyJhbGciOi..."
```

```json
{
  "data": [
    {
      "timestamp": "2026-06-15T10:30:00Z",
      "event_type": "user.login",
      "actor_type": "user",
      "actor_id": "user_abc123",
      "actor_email": "user@example.com",
      "resource_type": "session",
      "resource_id": "sess_xyz",
      "organization_id": "org_abc123",
      "metadata": {
        "ip": "192.168.1.1",
        "user_agent": "Mozilla/5.0..."
      }
    }
  ],
  "meta": {
    "total": 1,
    "from": "2026-01-01",
    "to": "2026-06-30",
    "format": "json"
  }
}
```

---

## Event Types

| Event Type | Description |
|---|---|
| `user.login` | User authenticated |
| `user.created` | New user registered |
| `user.updated` | User profile updated |
| `user.deleted` | User account deleted |
| `agent_token.created` | Agent token generated |
| `agent_token.revoked` | Agent token revoked |
| `step_authorization.granted` | Workflow step authorized |
| `step_authorization.denied` | Workflow step denied |
| `oauth2_client.created` | OAuth2 client registered |
| `oauth2_client.secret_rotated` | Client secret rotated |
| `api_key.created` | Admin API key generated |
| `api_key.revoked` | Admin API key revoked |

---

## Python Example

```python
import httpx
import csv
from io import StringIO

def export_audit_logs(token: str, org_id: str, from_date: str, to_date: str):
    response = httpx.get(
        "http://localhost:4000/api/audit-logs/export",
        headers={"Authorization": f"Bearer {token}"},
        params={
            "organization_id": org_id,
            "from": from_date,
            "to": to_date,
            "format": "csv",
            "limit": 50000
        }
    )
    response.raise_for_status()

    reader = csv.DictReader(StringIO(response.text))
    for row in reader:
        print(f"{row['timestamp']} | {row['event_type']} | {row['actor_id']}")

export_audit_logs("eyJhbGci...", "org_abc123", "2026-01-01", "2026-06-30")
```

---

## See Also

- [Agent Overview](../agents/overview.md) — Agent audit events
- [Organizations API](organizations.md) — Organization management
- [Roles API](roles.md) — Permission changes audit
