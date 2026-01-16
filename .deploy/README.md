# Deployment Scripts

Scripts para gestionar el despliegue de Thalamus a producción.

## 🔐 Configuración de Seguridad

### 1. Configurar variables de entorno

Crea tu archivo `.env` en la raíz del proyecto:

```bash
cp .env.example .env
```

### 2. Rotar token de DigitalOcean

⚠️ **IMPORTANTE**: El token anterior fue comprometido. Debes rotarlo:

1. Ve a: https://cloud.digitalocean.com/account/api/tokens
2. Encuentra el token que empieza con: `dop_v1_548295408...`
3. Click en "..." → "Delete"
4. Click en "Generate New Token"
5. Copia el nuevo token
6. Pégalo en `.env`:
   ```bash
   DIGITALOCEAN_TOKEN=dop_v1_tu_nuevo_token_aqui
   ```

### 3. Configurar acceso SSH

Asegúrate de tener configurada la clave SSH para acceder al VPS.

## 📜 Scripts Disponibles

### `list_droplets.py`

Lista droplets y dominios configurados en DigitalOcean. Lee el token desde `.env`.

**Uso:**
```bash
cd .deploy
python3 list_droplets.py
```

### `setup-ssl.sh`

Configura certificados SSL con Let's Encrypt en el VPS.

**Uso:**
```bash
cd .deploy
./setup-ssl.sh
```

## 🔒 Buenas Prácticas de Seguridad

✅ **SÍ hacer:**
- Usar `.env` para tokens y secrets
- Rotar tokens comprometidos inmediatamente
- Mantener `.env` en `.gitignore`

❌ **NO hacer:**
- Nunca hardcodear tokens en código
- Nunca commitear `.env` a git
- Nunca compartir tokens por canales inseguros
