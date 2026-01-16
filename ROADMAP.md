# 🗺️ Thalamus Dashboard - Roadmap & Progress Tracker

## 📊 Progress Overview

- **Total Tasks**: 45
- **Completed**: 20 (44%)
- **In Progress**: 1 (2%)
- **Pending**: 24 (53%)

---

## 🎯 Milestones

### Milestone 1: UI Foundation ✅ COMPLETED
**Status**: 9/9 tasks completed (100%)
**Completed**: 2026-01-01

- [x] Configurar Tailwind + daisyUI
- [x] Copiar sistema de colores OKLCH de ZEA Platform
- [x] Crear componentes de navegación (sidebar_link, nav_link)
- [x] Implementar theme toggle (dark/light/system)
- [x] Crear layout con sidebar profesional
- [x] Crear landing page moderna
- [x] Configurar Alpine.js para dropdowns
- [x] Crear Dashboard LiveView básico
- [x] Configurar rutas y pipelines

---

### Milestone 2: Dashboard Data Connection ✅ COMPLETED
**Status**: 5/5 tasks completed (100%)
**Target**: Week 1
**Completed**: 2026-01-01

- [x] **Task 2.1**: Conectar estadísticas de usuarios reales
  - File: `lib/thalamus_web/live/dashboard/index.ex`
  - Method: `count_users/0`
  - Estimated: 15 min
  - Completed: 2026-01-01

- [x] **Task 2.2**: Conectar estadísticas de OAuth2 clients
  - File: `lib/thalamus_web/live/dashboard/index.ex`
  - Method: `count_clients/0`
  - Estimated: 10 min
  - Completed: 2026-01-01

- [x] **Task 2.3**: Conectar estadísticas de organizations
  - File: `lib/thalamus_web/live/dashboard/index.ex`
  - Method: `count_organizations/0`
  - Estimated: 10 min
  - Completed: 2026-01-01

- [x] **Task 2.4**: Implementar contador de tokens activos
  - File: `lib/thalamus_web/live/dashboard/index.ex`
  - Method: `count_active_tokens/0`
  - Estimated: 20 min
  - Notes: Implemented using PostgreSQL tokens table
  - Completed: 2026-01-01

- [x] **Task 2.5**: Agregar actividad reciente al dashboard
  - File: `lib/thalamus_web/live/dashboard/index.ex`
  - Method: `load_recent_activity/0`
  - Features: Shows last 10 tokens with type, client, user, scopes, time, status
  - Estimated: 30 min
  - Completed: 2026-01-01

**Acceptance Criteria:**
- Dashboard muestra números reales desde la BD
- Los contadores se actualizan en tiempo real (LiveView)
- No hay errores en consola
- Performance < 100ms para cargar stats

---

### Milestone 3: OAuth2 Clients CRUD 📝 IN PROGRESS
**Status**: 6/7 tasks completed (85%)
**Target**: Week 1-2

- [x] **Task 3.1**: Crear LiveView Index para listar clients
  - File: `lib/thalamus_web/live/clients/index.ex`
  - Features: Lista con búsqueda, filtros (active/inactive), delete
  - Completed: 2026-01-02

- [x] **Task 3.2**: Crear formulario de creación de client
  - File: `lib/thalamus_web/live/clients/form.ex`
  - Features: Generar client_id/secret, validación, mostrar secret una vez
  - Completed: 2026-01-02

- [x] **Task 3.3**: Implementar edición de client
  - File: `lib/thalamus_web/live/clients/form.ex`
  - Features: Editar nombre, redirect_uris, scopes, grant types
  - Completed: 2026-01-02

- [x] **Task 3.4**: Implementar eliminación de client
  - Features: Confirmación con data-confirm, recarga automática
  - Method: `handle_event("delete")`
  - Completed: 2026-01-02

- [x] **Task 3.5**: Crear vista de detalle (Show)
  - File: `lib/thalamus_web/live/clients/show.ex`
  - Features: Stats de tokens (total, active, revoked), recent tokens, OAuth2 config
  - Completed: 2026-01-02

- [x] **Task 3.6**: Implementar rotación de client_secret
  - Features: Generar nuevo secret, mostrar en flash warning
  - Method: `handle_event("rotate_secret")`
  - Completed: 2026-01-02

- [ ] **Task 3.7**: Agregar tests para CRUD de clients
  - File: `test/thalamus_web/live/clients/index_test.exs`
  - Coverage: > 80%
  - Estimated: 1 hour

**Acceptance Criteria:**
- CRUD completo funcional
- Validaciones client-side y server-side
- Mensajes de éxito/error con flash
- Responsive en mobile
- Tests passing

---

### Milestone 4: Users Management 👥 PENDING
**Status**: 0/6 tasks completed (0%)
**Target**: Week 2

- [ ] **Task 4.1**: Crear LiveView Index para usuarios
  - File: `lib/thalamus_web/live/users/index.ex`
  - Estimated: 1 hour

- [ ] **Task 4.2**: Formulario crear/editar usuario
  - File: `lib/thalamus_web/live/users/form_component.ex`
  - Estimated: 1 hour

- [ ] **Task 4.3**: Vista de detalle de usuario
  - Features: Ver sesiones, tokens, organizaciones
  - Estimated: 45 min

- [ ] **Task 4.4**: Funcionalidad de reset password
  - Estimated: 30 min

- [ ] **Task 4.5**: Habilitar/deshabilitar usuarios
  - Features: Soft disable, invalidar sesiones
  - Estimated: 30 min

- [ ] **Task 4.6**: Tests de Users CRUD
  - Estimated: 1 hour

**Acceptance Criteria:**
- CRUD completo
- No exponer passwords en vistas
- Validaciones de email único
- Tests > 80% coverage

---

### Milestone 5: Organizations Management 🏢 PENDING
**Status**: 0/5 tasks completed (0%)
**Target**: Week 2-3

- [ ] **Task 5.1**: LiveView Index para organizations
  - Estimated: 1 hour

- [ ] **Task 5.2**: Formulario crear/editar organization
  - Estimated: 45 min

- [ ] **Task 5.3**: Vista de detalle (usuarios, clientes)
  - Estimated: 1 hour

- [ ] **Task 5.4**: Gestión de miembros de organización
  - Features: Agregar/remover usuarios, roles
  - Estimated: 1 hour

- [ ] **Task 5.5**: Tests
  - Estimated: 45 min

---

### Milestone 6: Token Management 🔑 PENDING
**Status**: 0/4 tasks completed (0%)
**Target**: Week 3

- [ ] **Task 6.1**: LiveView lista de access tokens activos
  - Features: Filtros por usuario/cliente, búsqueda
  - Estimated: 1.5 hours

- [ ] **Task 6.2**: Modal de introspección de token
  - Features: Ver claims, scopes, expiración
  - Estimated: 45 min

- [ ] **Task 6.3**: Funcionalidad de revocación de token
  - Features: Revocar individual o batch
  - Estimated: 30 min

- [ ] **Task 6.4**: Tests
  - Estimated: 45 min

---

### Milestone 7: Security & Auth 🔐 PENDING
**Status**: 0/5 tasks completed (0%)
**Target**: Week 3

- [ ] **Task 7.1**: Crear plug RequireAuth
  - File: `lib/thalamus_web/plugs/require_auth.ex`
  - Features: Redirect a login si no autenticado
  - Estimated: 30 min

- [ ] **Task 7.2**: Agregar plug al pipeline :dashboard
  - File: `lib/thalamus_web/router.ex`
  - Estimated: 15 min

- [ ] **Task 7.3**: Implementar assign_current_user
  - Features: Cargar usuario actual en assigns
  - Estimated: 20 min

- [ ] **Task 7.4**: Mejorar página de login con estilo ZEA
  - File: `lib/thalamus_web/controllers/session_html/new.html.heex`
  - Estimated: 1 hour

- [ ] **Task 7.5**: Tests de autenticación
  - Estimated: 45 min

**Acceptance Criteria:**
- Dashboard protegido con auth
- Redirect correcto después de login
- Session persistence
- Tests > 80%

---

### Milestone 8: Audit & Monitoring 📋 PENDING
**Status**: 0/3 tasks completed (0%)
**Target**: Week 4

- [ ] **Task 8.1**: LiveView para audit logs
  - Features: Lista paginada, filtros por fecha/usuario/acción
  - Estimated: 1.5 hours

- [ ] **Task 8.2**: Exportar logs a CSV
  - Features: Botón de export, generar CSV
  - Estimated: 45 min

- [ ] **Task 8.3**: Tests
  - Estimated: 30 min

---

### Milestone 9: Polish & UX 🎨 PENDING
**Status**: 0/5 tasks completed (0%)
**Target**: Week 4

- [ ] **Task 9.1**: Crear página 404 personalizada
  - File: `lib/thalamus_web/controllers/error_html/404.html.heex`
  - Estimated: 30 min

- [ ] **Task 9.2**: Crear página 500 personalizada
  - Estimated: 20 min

- [ ] **Task 9.3**: Agregar loading states en LiveViews
  - Features: Spinners, skeletons
  - Estimated: 1 hour

- [ ] **Task 9.4**: Mejorar mensajes de error
  - Features: Toast notifications, mejor UX
  - Estimated: 45 min

- [ ] **Task 9.5**: Documentación de usuario
  - File: `docs/DASHBOARD_USER_GUIDE.md`
  - Estimated: 1 hour

---

## 📈 Velocity Tracking

### Week 1 (Current)
- **Planned**: Milestone 2 (5 tasks)
- **Completed**: 0 tasks
- **Velocity**: 0 tasks/week

### Week 2 (Target)
- **Planned**: Milestone 3 (7 tasks)
- **Target Velocity**: 7 tasks/week

---

## 🚀 Quick Start Next Task

**Highest Priority**: Task 2.1 - Conectar estadísticas de usuarios

```bash
# 1. Leer el LiveView actual
cat lib/thalamus_web/live/dashboard/index.ex

# 2. Revisar repositorio de usuarios
cat lib/thalamus/infrastructure/repositories/postgresql_user_repository.ex

# 3. Implementar count_users/0

# 4. Verificar en browser
open http://localhost:4004/dashboard
```

---

## 📝 How to Update This File

Cuando completes una tarea:

1. Cambiar `[ ]` a `[x]`
2. Actualizar el contador de Progress Overview
3. Actualizar el % del Milestone
4. Si completas un Milestone, cambiar estado a ✅ COMPLETED
5. Actualizar fecha de completado
6. Commit changes:

```bash
git add ROADMAP.md
git commit -m "chore: update roadmap - completed task X.Y"
```

---

## 🎯 Definition of Done

Una tarea se considera **DONE** cuando:

- [x] Código implementado
- [x] Tests escritos y pasando
- [x] Documentación actualizada (si aplica)
- [x] Code review aprobado (si aplica)
- [x] Probado manualmente en browser
- [x] No rompe funcionalidad existente
- [x] Sin warnings de compilación

---

**Last Updated**: 2026-01-01
**Next Review**: Weekly
