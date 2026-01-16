╔══════════════════════════════════════════════════════════════════╗
║                 THALAMUS v1.0.0 - DOCKER SETUP                   ║
║                    ¡Listo en 2 comandos!                         ║
╚══════════════════════════════════════════════════════════════════╝

📦 PASO 1: Levantar con Docker
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   cd /Users/dev/Documents/zea/thalamus
   ./docker-start.sh

   ⏱️ Tiempo: 1-2 minutos la primera vez


🌐 PASO 2: Abrir en navegador
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Dashboard Principal:
   http://localhost:4100/dashboard

   Email Preview:
   http://localhost:4100/dev/mailbox

   API Keys (NUEVO):
   http://localhost:4100/dashboard/api-keys

   Settings (NUEVO):
   http://localhost:4100/dashboard/settings


📊 Ver logs (si hay problemas):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   docker-compose logs -f thalamus


🛑 Detener servicios:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   docker-compose down


🎯 PUERTOS USADOS (para evitar conflictos):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Thalamus:          4100  (no 4000)
   PostgreSQL:        5532  (no 5432)
   Redis:             6479  (no 6379)
   Adminer (DB UI):   8180  (no 8080)
   Redis Commander:   8181  (no 8081)


✅ LO QUE PUEDES PROBAR:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   ✓ Email Service (verificación, password reset, bienvenida)
   ✓ API Keys Management UI (crear, revocar, copiar keys)
   ✓ Settings Page (perfil, seguridad, tema)
   ✓ OAuth2 flows (authorization code, client credentials)
   ✓ Dashboard completo con sidebar colapsable


📖 DOCUMENTACIÓN COMPLETA:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   START_HERE.md              - Guía de inicio rápido
   DOCKER_QUICK_START.md      - Guía completa Docker
   V1_0_0_SUMMARY.md          - Resumen v1.0.0
   CHANGELOG_v1.0.0.md        - Release notes
   docs/guides/dashboard-user-guide.md  - Guía del Dashboard UI


¡Eso es todo! 🎉
