# 🔐 Pipeline de Seguridad - Vulnerator AI

## Descripción General

Este proyecto implementa una **pipeline de seguridad completa y gratuita** utilizando GitHub Actions, diseñada para ejecutarse automáticamente en cada PR antes de la aprobación.

## 🛡️ Componentes de Seguridad

### 1. **TruffleHog** - Detección de Secretos
- **Qué hace**: Escanea todo el historial de Git buscando secretos expuestos (API keys, tokens, passwords)
- **Cuándo se ejecuta**: En cada PR y push a ramas principales
- **Configuración**: `.github/workflows/security.yml` (job: `secrets-scan`)
- **Gravedad**: ❌ **BLOQUEA el PR** si encuentra secretos verificados

### 2. **CodeQL** - Análisis Estático de Código (SAST)
- **Qué hace**: Análisis profundo de seguridad del código Python
- **Detecta**: 
  - Inyección SQL
  - XSS (Cross-Site Scripting)
  - Deserialización insegura
  - Path traversal
  - Command injection
  - Vulnerabilidades CWE comunes
- **Cuándo se ejecuta**: En cada PR, push y semanalmente
- **Configuración**: `.github/workflows/security.yml` (job: `codeql-analysis`)
- **Resultados**: Visibles en la pestaña "Security" → "Code scanning alerts"

### 3. **Linting Python** - Calidad y Seguridad de Código
- **Herramientas**:
  - **flake8**: Detección de errores de sintaxis y estilo
  - **black**: Verificación de formato consistente
  - **bandit**: Análisis de seguridad específico para Python
- **Cuándo se ejecuta**: En cada PR
- **Configuración**: `.github/workflows/security.yml` (job: `python-lint`)
- **Gravedad**: ⚠️ **NO bloquea** pero genera reportes

### 4. **Safety** - Escaneo de Dependencias Vulnerables
- **Qué hace**: Verifica vulnerabilidades conocidas en dependencias Python
- **Escanea**: 
  - `docker/kali/requirements.txt`
  - `docker/mcp/requirements.txt`
- **Base de datos**: CVE y advisories de seguridad
- **Cuándo se ejecuta**: En cada PR
- **Configuración**: `.github/workflows/security.yml` (job: `dependency-scan`)

### 5. **Trivy** - Escaneo de Imágenes Docker
- **Qué hace**: Escanea vulnerabilidades en las imágenes Docker
- **Detecta**:
  - CVEs en paquetes del sistema operativo
  - Vulnerabilidades en dependencias
  - Misconfigurations
- **Imágenes escaneadas**:
  - `vulnerator-kali`
  - `vulnerator-mcp`
- **Cuándo se ejecuta**: En cada PR
- **Configuración**: `.github/workflows/security.yml` (job: `docker-scan`)
- **Gravedad**: Solo reporta CRITICAL y HIGH

### 6. **Hadolint** - Linting de Dockerfiles
- **Qué hace**: Valida best practices en Dockerfiles
- **Detecta**:
  - Uso de `latest` tag
  - Capas innecesarias
  - Secretos hardcodeados
  - Problemas de caché
- **Cuándo se ejecuta**: En cada PR
- **Configuración**: `.github/workflows/pr-checks.yml` (job: `dockerfile-lint`)

### 7. **Dependabot** - Actualizaciones Automáticas
- **Qué hace**: Crea PRs automáticos para actualizar dependencias
- **Monitorea**:
  - Dependencias Python (pip)
  - Imágenes base de Docker
  - GitHub Actions
- **Frecuencia**: Semanal
- **Configuración**: `.github/dependabot.yml`
- **Alertas de seguridad**: Automáticas en la pestaña "Security" → "Dependabot alerts"

## 🚀 Flujo de Trabajo

### Cuando abres un PR:

```
1. PR abierto
   ↓
2. Se ejecutan automáticamente:
   ├─ TruffleHog (secretos)
   ├─ CodeQL (vulnerabilidades)
   ├─ Python Lint (calidad)
   ├─ Safety (deps vulnerables)
   ├─ Trivy (Docker)
   ├─ Hadolint (Dockerfiles)
   └─ Validaciones de PR
   ↓
3. Resultados visibles en:
   - Checks del PR
   - Pestaña "Security"
   - Comentarios automáticos
   ↓
4. ✅ Si todos pasan → PR listo para revisar
   ❌ Si fallan → Corregir antes de merge
```

## 📊 Dónde Ver los Resultados

### En el PR:
- **Checks tab**: Estado de todos los workflows
- **Files changed**: Anotaciones inline de CodeQL y linters
- **Comentarios**: Resumen automático de quality checks

### En el Repositorio:
- **Security tab**:
  - `Code scanning alerts`: Vulnerabilidades de CodeQL y Trivy
  - `Dependabot alerts`: Dependencias vulnerables
  - `Secret scanning`: Secretos detectados (si está habilitado en el repo)

### Artifacts:
- Reportes JSON de bandit: `bandit-security-report`
- Reportes JSON de safety: `safety-reports`

## ⚙️ Configuración Inicial

### 1. Habilitar Funciones de Seguridad en GitHub

En tu repositorio, ve a **Settings** → **Security**:

```
☑️ Dependabot alerts (GRATIS)
☑️ Dependabot security updates (GRATIS)
☑️ Code scanning (GRATIS para repos públicos)
☑️ Secret scanning (GRATIS para repos públicos)
```

### 2. Subir los Archivos

```bash
git add .github/
git commit -m "feat: Agregar pipeline de seguridad completa"
git push origin main
```

### 3. Verificar que Funciona

1. Crea un PR de prueba
2. Ve a la pestaña "Actions" del repositorio
3. Deberías ver los workflows ejecutándose

## 🔧 Personalización

### Ajustar Severidad de TruffleHog

En `.github/workflows/security.yml`, línea del job `secrets-scan`:

```yaml
extra_args: --debug --only-verified  # Solo secretos verificados
# O para detectar todos:
extra_args: --debug  # Detecta todos los potenciales secretos
```

### Cambiar Reviewers de Dependabot

En `.github/dependabot.yml`:

```yaml
reviewers:
  - "tu-usuario-github"
  - "otro-colaborador"
```

### Deshabilitar un Check

Comenta o elimina el job correspondiente en los archivos YAML.

### Ajustar Frecuencia de Escaneos

En `.github/workflows/security.yml`:

```yaml
schedule:
  - cron: '0 2 * * 1'  # Lunes a las 2 AM
  # Cambiar a diario: '0 2 * * *'
  # Cambiar a mensual: '0 2 1 * *'
```

## 🐛 Troubleshooting

### TruffleHog encuentra falsos positivos

Crea un archivo `.trufflehogignore` en la raíz:

```
# Ejemplo de patrones a ignorar
docker/kali/tests/*.py
labs/**/*.py
```

### Safety reporta vulnerabilidad no crítica

Si necesitas ignorar temporalmente:

```bash
# En el job dependency-scan, agregar:
safety check --ignore=51457  # Reemplaza con el CVE ID
```

### CodeQL tarda mucho

Es normal en la primera ejecución. Los escaneos posteriores son incrementales y más rápidos.

## 📈 Métricas y Reportes

### Ver Tendencias de Seguridad

1. Ve a **Insights** → **Security**
2. Gráficos de:
   - Alertas abiertas vs cerradas
   - Tiempo de resolución
   - Tipos de vulnerabilidades

### Exportar Reportes

Los artifacts JSON están disponibles por 90 días y pueden descargarse desde la pestaña "Actions".

## 🎯 Best Practices

1. **No ignores los warnings**: Revisa cada alerta aunque no bloquee el PR
2. **Actualiza dependencias regularmente**: Aprueba los PRs de Dependabot
3. **Revisa los escaneos semanales**: Aunque no haya PR, el scan semanal puede detectar nuevas vulnerabilidades
4. **Mantén actualizado `.env.example`**: Nunca commites `.env` real
5. **Usa GitHub Secrets**: Para CI/CD variables sensibles

## 🆓 Costos

**TODO ES GRATUITO** para repositorios públicos y privados (con límites generosos):

- ✅ GitHub Actions: 2,000 minutos/mes gratis
- ✅ Dependabot: Ilimitado
- ✅ CodeQL: Gratis para repos públicos
- ✅ TruffleHog: Open source, gratis
- ✅ Trivy: Open source, gratis

Para repos privados, los minutos se consumen, pero la cuota gratuita suele ser suficiente.

## 📚 Referencias

- [TruffleHog Docs](https://github.com/trufflesecurity/trufflehog)
- [CodeQL Docs](https://codeql.github.com/docs/)
- [Trivy Docs](https://aquasecurity.github.io/trivy/)
- [Dependabot Docs](https://docs.github.com/en/code-security/dependabot)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides)

---

**Mantenido por**: [@irraz](https://github.com/irraz)  
**Última actualización**: 2026-10-23
