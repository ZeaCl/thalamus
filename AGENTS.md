# Thalamus — Agent & CI/CD Directives

## 🚀 CI/CD & Despliegue (Google Cloud Build)

Thalamus utiliza **100% Google Cloud Build** como plataforma de CI/CD (migración completa de epic ZeaCl/zea-cicd#35). **No se utiliza GitHub Actions**.

- **Pipeline de Producción:** Definido en `cloudbuild.yaml`.
- **Compilación de Imagen:** Docker multi-stage (`--target runtime`).
- **Artifact Registry:** `southamerica-west1-docker.pkg.dev/zea-platform/zea/thalamus:latest`.
- **Runtime:** Instancia GCP `thalamus-gcp` (34.176.56.101) con auto-deploy / reload.

## 🧪 Validaciones Locales

Antes de enviar PR o hacer merge a `main`:
```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```
