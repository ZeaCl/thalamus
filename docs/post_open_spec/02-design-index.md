# Design Document - Index
## Thalamus: Identity Server for the Agentic Economy

**Document Version:** 1.0
**Date:** January 16, 2026
**Status:** Draft - Awaiting Approval
**Prerequisites:** [Requirements Document](01-requirements.md) - APPROVED

---

## Executive Summary

This document presents the technical architecture for Thalamus's evolution into a high-performance identity server optimized for the Agentic Economy. The design leverages **Elixir/BEAM's technical moat** to achieve <5ms p99 latency for M2M token generation while maintaining strict **Clean Architecture** and **SOLID principles**.

### Key Design Decisions

1. **ETS-First Caching**: Replace Redis with ETS (Erlang Term Storage) for 6-10x faster in-memory operations
2. **Process-Per-Request**: Leverage BEAM's lightweight processes for isolated, concurrent token generation
3. **Additive Architecture**: All new agent features extend existing OAuth2 infrastructure without breaking changes
4. **Port-Based Abstraction**: New agent repositories and services follow existing port/adapter pattern
5. **Feature Flag Isolation**: `ENABLE_AGENT_TOKENS` flag allows gradual rollout

---

## Design Documents

### Core Architecture
- **[02-design-architecture.md](02-design-architecture.md)** - System architecture overview, request flows, layer mapping

### Component Design
- **[02-design-components.md](02-design-components.md)** - Domain, Application, Infrastructure, and Presentation layer components

### Data & Persistence
- **[02-design-database.md](02-design-database.md)** - Database schema, migrations, multi-tenant isolation

### Performance & Testing
- **[02-design-performance.md](02-design-performance.md)** - Performance optimization, caching strategies, testing approach

### Deployment & Operations
- **[02-design-deployment.md](02-design-deployment.md)** - Infrastructure, migration path, monitoring, SDKs

---

## Quick Reference

### Performance Targets
- **p99 Latency**: <5ms for M2M token generation
- **Throughput**: 10,000 RPS per node (c7g.2xlarge)
- **Cache Hit Rate**: >95% for token introspection
- **Cost**: $343/month for 10M tokens/month

### Technology Stack
- **Language**: Elixir 1.17+ on OTP 27+
- **Database**: PostgreSQL 16+ (RDS db.m7g.large)
- **Cache**: ETS (in-memory, node-local)
- **Infrastructure**: AWS Graviton (ARM64)

### Key Endpoints
- `POST /oauth/agent-token` - Generate agent token with delegation
- `POST /oauth/introspect` - Validate token (<3ms p99)
- `POST /oauth/revoke` - Revoke token + delegation chain

---

## Pending Design Decisions

1. **MCP Gateway Transport**: WebSocket support or stdio-only for MVP?
2. **Agent Token TTL**: Default 5 minutes, configurable per client?
3. **Delegation Chain Visualization**: Tree view in dashboard (defer to v1.1)?
4. **AAuth Approval UI**: Custom LiveView or integrate with existing dashboard?
5. **SDK Priority**: Which SDK after Python? (Recommendation: TypeScript)

---

## Next Steps

1. Review and approve design documents
2. Address pending design decisions above
3. Proceed to Phase 3: Tasks (Implementation Plan with checkboxes)
