# Design Documents - Navigation

Los documentos de diseño están divididos en archivos más pequeños para mejor navegación:

## Orden de Lectura Sugerido

1. **[02-design-index.md](02-design-index.md)** - ⭐ Comienza aquí
   - Executive summary
   - Decisiones clave de diseño
   - Índice de todos los documentos

2. **[02-design-architecture.md](02-design-architecture.md)** - Arquitectura del Sistema
   - High-level architecture diagram
   - Request flows (M2M token generation, agent delegation)
   - Clean Architecture layer mapping
   - MCP Gateway architecture

3. **[02-design-components.md](02-design-components.md)** - Componentes por Capa
   - Domain layer: AgentToken entity, Value Objects
   - Application layer: GenerateAgentToken use case, Ports
   - Infrastructure layer: PostgreSQL repository, ETS cache
   - Presentation layer: Controllers, MCP Gateway

4. **[02-design-database.md](02-design-database.md)** - Base de Datos
   - Entity-Relationship diagram
   - Migration strategy (additive-only)
   - Multi-tenant isolation (RLS)
   - Query performance optimization

5. **[02-design-performance.md](02-design-performance.md)** - Performance y Testing
   - ETS vs Redis comparison (6x faster)
   - Caching strategy (3-tier)
   - Testing strategy (test pyramid, benchmarks)
   - Observability (Prometheus, Grafana)

6. **[02-design-deployment.md](02-design-deployment.md)** - Deployment y Operaciones
   - Production infrastructure (AWS Graviton)
   - Cost breakdown ($343/month)
   - Migration path (zero-downtime)
   - SDK architecture (Python, TypeScript, Go, Rust, Java, Kotlin)
   - Security considerations

## Tamaño de Archivos

- **02-design-index.md**: 3KB
- **02-design-architecture.md**: 7.2KB
- **02-design-components.md**: 9.9KB
- **02-design-database.md**: 4.8KB
- **02-design-performance.md**: 7.2KB
- **02-design-deployment.md**: 8.5KB

**Total**: ~40KB (vs 1.5MB archivo original)

## Quick Links

- [Requirements Document](01-requirements.md) - Prerequisito aprobado
- [Design Index](02-design-index.md) - Punto de entrada principal
