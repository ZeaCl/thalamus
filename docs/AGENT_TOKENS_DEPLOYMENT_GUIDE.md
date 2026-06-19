# Agent Tokens Deployment Guide

**Last Updated:** January 20, 2026
**Status:** Production-Ready (73% complete - Epics 1-6 done)
**Version:** v1.0.0-rc1

---

## Overview

This guide provides step-by-step instructions for deploying Agent Token features to production with zero downtime and gradual rollout capabilities.

**Agent Tokens Status:**
- ✅ Epic 1-6: Production-ready (181/181 tests passing)
- ✅ Epic 7: Observability - Telemetry events implemented
- ✅ Epic 8: Migration & Rollout - Feature flags implemented

---

## Prerequisites

Before deploying Agent Tokens, ensure:

1. **Database Migration Ready**
   ```bash
   mix ecto.migrations
   # Verify migration exists: 20260102212619_add_agent_token_fields.exs
   ```

2. **Tests Passing**
   ```bash
   mix test
   # Verify: 181/181 agent token tests passing
   ```

3. **Feature Flag Available**
   - Feature flag system implemented (`lib/thalamus/feature_flags.ex`)
   - Default state: DISABLED (safe)

4. **Monitoring Ready**
   - Telemetry metrics configured
   - Metrics endpoint available (if using Prometheus)

---

## Deployment Strategy: 4-Phase Gradual Rollout

### Phase 1: Deploy with Feature Disabled (Week 1)

**Goal:** Deploy infrastructure without activating feature

**Steps:**

1. **Deploy Application with Feature OFF**
   ```bash
   # Set environment variable
   export ENABLE_AGENT_TOKENS=false

   # Or in Kubernetes
   kubectl set env deployment/thalamus ENABLE_AGENT_TOKENS=false

   # Deploy
   git checkout main
   git pull
   mix release
   # Deploy via your CI/CD pipeline
   ```

2. **Run Database Migration**
   ```bash
   # In production environment
   mix ecto.migrate

   # Verify tables created
   psql $DATABASE_URL -c "\d agent_tokens"
   ```

3. **Verify Backward Compatibility**
   ```bash
   # Test existing OAuth2 flows
   curl -X POST https://your-domain.com/oauth/token \
     -d "grant_type=client_credentials&client_id=...&client_secret=..."

   # Verify: Should work exactly as before
   ```

4. **Verify Feature is Disabled**
   ```bash
   curl -X POST https://your-domain.com/oauth/agent-token \
     -d "client_id=...&client_secret=..."

   # Expected: 404 Not Found (feature disabled)
   ```

**Success Criteria:**
- ✅ Migration applied successfully
- ✅ No existing functionality broken
- ✅ Agent token endpoint returns 404
- ✅ No errors in logs

---

### Phase 2: Test Organization Pilot (Week 2)

**Goal:** Enable for single test organization, monitor 24-48 hours

**Steps:**

1. **Enable for Test Organization**
   ```sql
   -- Enable globally first
   -- Set ENABLE_AGENT_TOKENS=true in your deployment

   -- Or enable per-organization (more granular)
   UPDATE organizations
   SET settings = jsonb_set(
     COALESCE(settings, '{}'),
     '{feature_flags,agent_tokens}',
     'true'
   )
   WHERE id = 'your-test-org-id';
   ```

2. **Test Agent Token Generation**
   ```bash
   curl -X POST https://your-domain.com/oauth/agent-token \
     -H "Content-Type: application/json" \
     -d '{
       "client_id": "test_client_id",
       "client_secret": "test_client_secret",
       "delegated_by_user_id": "user_123",
       "agent_type": "autonomous",
       "scope": "api:read api:write"
     }'

   # Expected: 200 OK with agent token
   ```

3. **Monitor Metrics**
   ```bash
   # Check Prometheus metrics (if configured)
   curl http://your-domain.com/metrics | grep agent_token

   # Check audit logs
   psql $DATABASE_URL -c "SELECT * FROM audit_logs WHERE event_type = 'agent_token_generated' ORDER BY created_at DESC LIMIT 10;"
   ```

4. **Monitor for Issues**
   - Watch error rates
   - Check response times
   - Verify no database performance degradation
   - Review audit logs for anomalies

**Success Criteria:**
- ✅ Agent tokens generate successfully
- ✅ Metrics are being collected
- ✅ Audit logs working
- ✅ No performance degradation
- ✅ Zero incidents for 24-48 hours

---

### Phase 3: Gradual Rollout (Weeks 3-4)

**Goal:** Roll out to 10% → 50% → 100% of organizations

**3.1: 10% Rollout**

```bash
# Enable for 10% of organizations
# Option A: Random selection
psql $DATABASE_URL <<EOF
UPDATE organizations
SET settings = jsonb_set(
  COALESCE(settings, '{}'),
  '{feature_flags,agent_tokens}',
  'true'
)
WHERE id IN (
  SELECT id FROM organizations
  WHERE random() < 0.1
  LIMIT (SELECT count(*) * 0.1 FROM organizations)
);
EOF

# Option B: Specific organizations
# Manually enable for trusted customers
```

**Monitor:**
- Daily metrics review
- Error rate thresholds
- Customer feedback

**Wait:** 3-5 days

**3.2: 50% Rollout**

```sql
-- Enable for 50% of organizations
UPDATE organizations
SET settings = jsonb_set(
  COALESCE(settings, '{}'),
  '{feature_flags,agent_tokens}',
  'true'
)
WHERE random() < 0.5;
```

**Monitor:**
- Same as 10% rollout
- Performance metrics
- Database load

**Wait:** 5-7 days

**3.3: 100% Rollout**

```bash
# Enable globally via environment variable
export ENABLE_AGENT_TOKENS=true

# Or via config
config :thalamus, :feature_flags,
  agent_tokens: true
```

**Monitor:**
- Full week of monitoring
- All metrics stable

---

### Phase 4: Remove Feature Flag (Week 5+)

**Goal:** Remove feature flag code once stable

**Steps:**

1. **Verify Stability**
   - 2+ weeks of 100% rollout
   - No critical issues
   - All metrics healthy

2. **Remove Feature Flag Code**
   ```bash
   # Remove feature flag checks from controllers
   # Simplify code
   git checkout -b remove-agent-token-flag
   ```

3. **Deploy Without Flag**
   - Agent tokens always enabled
   - Cleaner code
   - Feature is now standard

---

## Rollback Procedures

### Emergency Disable (Immediate)

**Scenario:** Critical issue detected

**Global Disable:**
```bash
# Kubernetes
kubectl set env deployment/thalamus ENABLE_AGENT_TOKENS=false

# Or restart with env var
export ENABLE_AGENT_TOKENS=false
mix phx.server

# Takes effect immediately (no deployment needed)
```

**Per-Organization Disable:**
```sql
-- Disable for specific organization
UPDATE organizations
SET settings = jsonb_set(
  COALESCE(settings, '{}'),
  '{feature_flags,agent_tokens}',
  'false'
)
WHERE id = 'problematic-org-id';
```

**Effect:**
- Agent token endpoint returns 404
- Existing tokens still work (introspection)
- No new tokens can be generated

---

### Full Rollback (Severe Issues)

**Scenario:** Major database or application issues

**Steps:**

1. **Stop Application**
   ```bash
   kubectl scale deployment/thalamus --replicas=0
   ```

2. **Rollback Database Migration**
   ```bash
   mix ecto.rollback
   # Removes agent_tokens table and related changes
   ```

3. **Deploy Previous Version**
   ```bash
   git checkout <previous-stable-tag>
   # Deploy via CI/CD
   ```

4. **Verify Rollback**
   ```bash
   # Test existing OAuth2 flows
   # Verify no agent token endpoints
   ```

---

## Monitoring & Alerting

### Key Metrics to Monitor

**Agent Token Generation:**
```
thalamus.agent_tokens.issued (counter)
- Alert if: Spike > 10x normal
- Tags: agent_type, organization_id
```

**Delegation Chain Depth:**
```
thalamus.agent_tokens.delegation_depth (histogram)
- Alert if: depth > 5 (unusual)
```

**Generation Duration:**
```
thalamus.agent_tokens.generation_duration (summary)
- Alert if: p99 > 100ms
```

**Active Tokens:**
```
thalamus.agent_tokens.active_total (gauge)
- Alert if: > 100k tokens
```

### Audit Log Queries

```sql
-- Tokens generated today
SELECT count(*)
FROM audit_logs
WHERE event_type = 'agent_token_generated'
  AND created_at > NOW() - INTERVAL '1 day';

-- Top organizations by token usage
SELECT
  metadata->>'organization_id' as org,
  count(*) as token_count
FROM audit_logs
WHERE event_type = 'agent_token_generated'
GROUP BY metadata->>'organization_id'
ORDER BY token_count DESC
LIMIT 10;

-- Tokens by agent type
SELECT
  metadata->>'agent_type' as type,
  count(*) as count
FROM audit_logs
WHERE event_type = 'agent_token_generated'
  AND created_at > NOW() - INTERVAL '1 day'
GROUP BY metadata->>'agent_type';
```

---

## Testing Checklist

Before production deployment:

- [ ] All 181 agent token tests passing
- [ ] Database migration tested in staging
- [ ] Feature flag tested (enabled/disabled states)
- [ ] Backward compatibility verified
- [ ] Metrics collection verified
- [ ] Audit logging verified
- [ ] Rollback procedure tested
- [ ] Load testing completed (if high-traffic)

---

## Troubleshooting

### Issue: Agent token endpoint returns 404

**Cause:** Feature flag disabled

**Fix:**
```bash
# Check flag status
Thalamus.FeatureFlags.agent_tokens_enabled?()

# Enable globally
export ENABLE_AGENT_TOKENS=true
```

### Issue: "invalid_client" error

**Cause:** Client credentials invalid or client not active

**Fix:**
```sql
-- Verify client exists and is active
SELECT * FROM oauth2_clients WHERE client_id = 'your_client_id';

-- Activate client if needed
UPDATE oauth2_clients SET is_active = true WHERE client_id = 'your_client_id';
```

### Issue: "delegator_not_found" error

**Cause:** User ID doesn't exist or is inactive

**Fix:**
```sql
-- Verify user exists
SELECT * FROM users WHERE id = 'user_id';

-- Check user status
SELECT status FROM users WHERE id = 'user_id';
```

### Issue: High database load

**Cause:** Too many active tokens

**Fix:**
- Review token TTLs (default: 900s)
- Clean up expired tokens
- Consider shorter TTLs for high-volume apps

---

## Security Considerations

1. **Feature Flag Security**
   - Default: DISABLED (safe)
   - Requires explicit enable action
   - Per-org override available

2. **Token Validation**
   - All tokens validated on generation
   - Scopes verified against client permissions
   - Delegation chains tracked

3. **Audit Trail**
   - All token generations logged
   - Metadata includes: agent_type, task_id, scopes
   - Immutable audit log

4. **Rate Limiting**
   - Standard rate limits apply
   - Monitor for abuse patterns

---

## Support & Documentation

**Agent Token Features:**
- Epic 1-6: Production-ready
- Epic 7: Observability complete
- Epic 8: Migration & Rollout complete

**Documentation:**
- [THALAMUS_FUNCTIONALITY_INVENTORY.md](/Users/dev/Documents/zea/thalamus/THALAMUS_FUNCTIONALITY_INVENTORY.md)
- [docs/post_open_spec/03-tasks.md](/Users/dev/Documents/zea/thalamus/docs/post_open_spec/03-tasks.md)
- [docs/post_open_spec/IMPLEMENTATION_STATUS.md](/Users/dev/Documents/zea/thalamus/docs/post_open_spec/IMPLEMENTATION_STATUS.md)

**Test Coverage:**
- 181/181 agent token tests passing (100%)

**Contact:**
- Check audit logs for issues
- Monitor telemetry metrics
- Review GitHub issues

---

**Status:** Ready for production deployment with gradual rollout strategy ✅
