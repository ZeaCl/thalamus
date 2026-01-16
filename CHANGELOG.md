# Changelog

All notable changes to ZEA Thalamus will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2026-01-02

### Added - Web Dashboard Polish & UX
- ✨ **Breadcrumb navigation** component across all dashboard pages
  - Reusable `<.breadcrumbs items={[...]}/>`component in `ThalamusWeb.Layouts`
  - Hierarchical navigation: Dashboard > Section > Subsection > Current
  - Home icon for first element, chevron separators
  - Implemented in 12 pages (Clients, Users, Organizations, Tokens, Audit Logs)
- ✨ **Loading state components** for better perceived performance
  - `<.spinner />` - Animated loading spinner with customizable size
  - `<.skeleton />` - Placeholder loading with pulse animation
  - `<.table_skeleton rows={5} />` - Table loading state
- 🎨 **Improved navigation** - All components properly imported in html_helpers

### Changed
- 📈 **Test coverage** increased from 78% to 80% (189 tests)
- 📊 **Progress** from 77% to 84% (36/43 tasks completed)
- 📝 Updated documentation with UX improvements

### Fixed
- 🐛 Fixed circular dependency in `ThalamusWeb.Layouts` module
- 🐛 Removed unused "Back to..." links replaced by breadcrumbs

## [0.8.0] - 2026-01-02

### Added - Audit & Monitoring
- ✨ **Audit Logs** system with immutable security trail
  - Database migration for `audit_logs` table with 9 optimized indexes
  - `AuditLogSchema` with 22 event types (authentication, tokens, MFA, etc.)
  - Automatic persistence enabled in production
  - Data sanitization (email masking, token truncation)
- ✨ **Audit Logs Dashboard** (`/dashboard/audit-logs`)
  - Advanced filtering: search, event type, date range
  - Display last 100 events with color-coded badges
  - Shows: timestamp, event, user, organization, IP, metadata
  - 15 comprehensive tests
- 📊 Compliance features for GDPR, HIPAA, PCI-DSS, SOC 2

### Changed
- 📈 **Test coverage** from 75% to 78% (174 → 189 tests)
- 📊 **Progress** from 70% to 77% (30/43 → 33/43 tasks)

## [0.7.0] - 2026-01-02

### Added - Organizations Management
- ✨ **Organizations CRUD** complete implementation
  - Organizations Index LiveView with search and filters
  - Organizations Form LiveView (create/edit)
  - Organizations Show LiveView (details, statistics, user management)
  - Plan management (Free, Starter, Professional, Enterprise)
  - Organization verification and suspension
  - 32 comprehensive tests
- 🔐 **Security & Authentication**
  - `RequireAuth` plug for dashboard protection
  - Session-based authentication with `return_to` support
  - All `/dashboard/*` routes protected
  - 13 security tests

### Changed
- 📈 **Test coverage** from 72% to 75% (142 → 174 tests)
- 📊 **Progress** from 65% to 70% (28/43 → 30/43 tasks)

## [0.6.0] - 2026-01-02

### Added - Users Management
- ✨ **Users CRUD** complete implementation
  - Users Index LiveView with search and filters
  - Users Form LiveView (create/edit)
  - Users Show LiveView (details, password reset, status management)
  - User status management (active, suspended, pending_verification)
  - Multi-factor authentication support
  - 63 comprehensive tests

### Changed
- 📈 **Test coverage** from 68% to 72% (79 → 142 tests)
- 📊 **Progress** from 60% to 65% (26/43 → 28/43 tasks)

### Fixed
- 🐛 Fixed form validation edge cases
- 🐛 Improved error handling in LiveView components

## [0.5.0] - 2026-01-02

### Added - OAuth2 Clients Management
- ✨ **OAuth2 Clients CRUD** complete implementation
  - Clients Index LiveView with search and filters
  - Clients Form LiveView (create/edit)
  - Clients Show LiveView (details, secret rotation, token stats)
  - Automatic client_id and client_secret generation
  - Client secret rotation with confirmation
  - Grant types configuration (authorization_code, client_credentials, refresh_token)
  - Scopes and redirect URIs management
  - 35 comprehensive tests

### Fixed
- 🐛 Fixed: `show.ex` querying tokens by `client_id_string` instead of `client.id`
- 🎨 Improved form spacing and input styling
- 🎨 Removed double border on input focus

## [0.4.0] - 2026-01-01

### Added - Dashboard Data Connection
- ✨ **Real-time statistics** on dashboard
  - User count from database
  - OAuth2 client count
  - Active token count
  - Organization count
  - Recent token activity table (last 10 tokens)

### Changed
- 🔄 Connected dashboard to actual database data
- 📊 Replaced mock data with real queries

## [0.3.0] - 2026-01-01

### Added - UI Foundation
- ✨ **Modern landing page** at `/`
  - Hero section with features
  - ZEA Platform design system
  - Responsive layout
- ✨ **Admin Dashboard** at `/dashboard`
  - Sidebar navigation with icons
  - Stats cards (users, clients, tokens, organizations)
  - Recent activity table
  - Dark/Light/System theme support
  - Alpine.js for interactivity
- 🎨 **Design System**
  - Tailwind CSS + daisyUI integration
  - Custom color palette
  - Responsive components
  - Professional typography

## [0.2.0] - 2025-10-26

### Added - Admin API Keys
- ✨ **Admin API Keys** for service-to-service authentication
  - Create API keys with scoped permissions
  - Bcrypt hashing for secure storage
  - Key rotation support
  - Expiration date support
  - Revocation support
  - Last used tracking
  - Audit logging for all operations
- 📚 **Admin API Keys Guide** - Complete documentation
- 🧪 **Comprehensive tests** for Admin API Keys endpoints

### Security
- 🔒 API keys hashed with Bcrypt (never stored in plaintext)
- 🔒 Prefix-based lookup for efficient authentication
- 🔒 Scoped permissions (clients:read, clients:write, etc.)

## [0.1.0] - 2025-10-25

### Added - Core OAuth2 Implementation
- ✨ **OAuth2 2.0 Server** (RFC 6749)
  - Authorization Code Grant with PKCE (RFC 7636)
  - Client Credentials Grant
  - Refresh Token Grant
  - Token Introspection (RFC 7662)
  - Token Revocation (RFC 7009)
  - OpenID Connect Userinfo endpoint
- 🔐 **Authentication & Security**
  - Multi-Factor Authentication (TOTP)
  - Backup codes for account recovery
  - Email verification
  - Password reset
  - Rate limiting (per IP, user, client)
  - CORS configuration
  - Security headers (CSP, HSTS, X-Frame-Options)
- 🏢 **Multi-Tenancy**
  - Organization management
  - Role-Based Access Control (RBAC)
  - Flexible plans (Free, Starter, Professional, Enterprise)
- 🏗️ **Clean Architecture**
  - Domain Layer with Value Objects and Entities
  - Application Layer with Use Cases and Ports
  - Infrastructure Layer with Repositories
  - Presentation Layer with Phoenix Controllers
  - SOLID principles strictly enforced
- 📚 **Complete API**
  - REST API for user management
  - REST API for organization management
  - REST API for OAuth2 client management
  - OpenAPI 3.0 specification
- 🧪 **Testing**
  - Domain layer: 100% coverage
  - Application layer: 100% coverage
  - Controllers: 100% coverage (all critical paths)
  - Overall: 75% coverage
- 🐳 **Docker Support**
  - Multi-stage Dockerfile
  - Docker Compose with PostgreSQL and Redis
  - Production-ready configuration

### Documentation
- 📖 Complete README with quick start
- 📖 Integration Guide with examples
- 📖 Architecture documentation
- 📖 Deployment guide
- 📖 OpenAPI specification

---

## Release Notes

### Version 0.9.0 Highlights
This release focuses on **user experience improvements** for the admin dashboard:
- **Better Navigation**: Breadcrumbs on all pages help users understand where they are
- **Professional Loading States**: Spinner and skeleton components improve perceived performance
- **Consistent Design**: Unified component system across all dashboard pages

### Version 0.8.0 Highlights
This release adds **enterprise-grade audit logging**:
- **Immutable Security Trail**: All security events are logged permanently
- **Advanced Filtering**: Search and filter by user, event type, date range
- **Compliance Ready**: Supports GDPR, HIPAA, PCI-DSS, SOC 2 requirements

### Version 0.7.0 Highlights
This release completes the **management dashboard** with organizations and security:
- **Organizations Management**: Full CRUD with plan management
- **Dashboard Security**: All routes protected with session authentication
- **Better UX**: Improved navigation and user feedback

---

## Upgrade Guide

### From 0.8.0 to 0.9.0
No breaking changes. Update dependencies and restart:
```bash
mix deps.get
mix compile
```

### From 0.7.0 to 0.8.0
Run the audit logs migration:
```bash
mix ecto.migrate
```

### From 0.6.0 to 0.7.0
No breaking changes. Update dependencies:
```bash
mix deps.get
mix compile
```

---

[0.9.0]: https://github.com/yourusername/thalamus/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/yourusername/thalamus/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/yourusername/thalamus/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/yourusername/thalamus/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/yourusername/thalamus/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/yourusername/thalamus/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/yourusername/thalamus/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/yourusername/thalamus/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/yourusername/thalamus/releases/tag/v0.1.0
