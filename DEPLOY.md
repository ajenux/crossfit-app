# Deploy Instructions

## Estado actual
- Backend desplegado en Railway ✅
- URL del backend: `https://crossfit-app-production-fcf2.up.railway.app`
- GitHub Actions workflow listo (`.github/workflows/deploy-web.yml`) ✅
- Variable `API_URL` agregada en GitHub repo secrets ✅

## Pendiente: Configurar Netlify

### Paso 1 — Crear sitio en Netlify
1. Ir a netlify.com (ya logueado)
2. Crear un sitio vacío arrastrando cualquier archivo HTML
3. O usar Netlify CLI:
   ```bash
   npm install -g netlify-cli
   netlify login
   netlify sites:create --name crossfit-app-demo
   ```

### Paso 2 — Obtener Site ID
- Netlify → tu sitio → **Site configuration** → **General** → copiar **Site ID**

### Paso 3 — Obtener Personal Access Token
- Netlify → avatar arriba a la derecha → **User settings** → **Applications** → **Personal access tokens** → **New access token**

### Paso 4 — Agregar secrets en GitHub
- Ir a: github.com/ajenux/crossfit-app → **Settings** → **Secrets and variables** → **Actions**
- Agregar:
  - `NETLIFY_AUTH_TOKEN` = (token del paso 3)
  - `NETLIFY_SITE_ID` = (site ID del paso 2)

### Paso 5 — Disparar el deploy
```bash
git commit --allow-empty -m "Trigger Netlify deploy"
git push origin master
```
O hacer cualquier cambio en master — el workflow se dispara automáticamente.

### Paso 6 — Verificar
- GitHub → Actions → ver que el workflow `Deploy Flutter Web to Netlify` termine en verde
- Abrir la URL de Netlify y probar la app

## Variables ya configuradas en Railway (backend)
| Variable | Valor |
|---|---|
| `JWT_SECRET` | configurado ✅ |
| `SPRING_PROFILES_ACTIVE` | `demo` ✅ |
| `SPRING_DATASOURCE_URL` | referencia a Postgres ✅ |
| `SPRING_DATASOURCE_USERNAME` | referencia a Postgres ✅ |
| `SPRING_DATASOURCE_PASSWORD` | referencia a Postgres ✅ |

## Cuentas demo (creadas por DataInitializer)
| Email | Password | Rol |
|---|---|---|
| `coach@demo.com` | `Demo1234` | COACH |
| `athlete1@demo.com` | `Demo1234` | ATHLETE |
| `athlete2@demo.com` | `Demo1234` | ATHLETE |