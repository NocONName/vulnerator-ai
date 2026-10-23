#!/bin/bash
# Script para ejecutar los checks de seguridad LOCALMENTE antes de push
# Simula lo que ejecutará la pipeline de GitHub Actions
#
# Uso: .github/scripts/local-security-check.sh [--fix]

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
FIX_MODE=false
if [[ "$1" == "--fix" ]]; then
    FIX_MODE=true
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       🔐 LOCAL SECURITY CHECK - Vulnerator AI                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

FAILED_CHECKS=0
TOTAL_CHECKS=0

# Función para reportar resultado
report_check() {
    local check_name=$1
    local status=$2
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ $status -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $check_name"
    else
        echo -e "${RED}✗${NC} $check_name"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# ==============================================================================
# 1. VERIFICAR DEPENDENCIAS
# ==============================================================================
echo -e "\n${YELLOW}[1/7]${NC} Verificando dependencias..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker no está instalado${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python3 no está instalado${NC}"
    exit 1
fi

# Verificar/instalar herramientas Python
pip3 install --quiet --upgrade pip 2>/dev/null || true
pip3 install --quiet flake8 black bandit safety 2>/dev/null || true

echo -e "${GREEN}✓${NC} Dependencias verificadas"

# ==============================================================================
# 2. DETECCIÓN DE SECRETOS (TruffleHog simulado con grep)
# ==============================================================================
echo -e "\n${YELLOW}[2/7]${NC} 🔐 Escaneando secretos..."

# Patrones comunes de secretos
SECRET_PATTERNS=(
    "AKIA[0-9A-Z]{16}"  # AWS Access Key
    "(?i)api[_-]?key['\"]?\s*[:=]\s*['\"][0-9a-zA-Z]{32,45}['\"]"
    "(?i)password['\"]?\s*[:=]\s*['\"][^'\"]{8,}['\"]"
    "(?i)secret['\"]?\s*[:=]\s*['\"][0-9a-zA-Z]{32,}['\"]"
    "-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----"
)

SECRETS_FOUND=false
for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -rE "$pattern" . \
        --exclude-dir={.git,.venv,venv,node_modules,.pytest_cache,__pycache__} \
        --exclude={"*.log","*.pyc",".secrets.baseline"} \
        --exclude-dir=".github" \
        2>/dev/null | grep -v ".env.example" | grep -v "QUICKSTART.md" | grep -v "local-security-check.sh"; then
        SECRETS_FOUND=true
    fi
done

if [[ "$SECRETS_FOUND" == true ]]; then
    report_check "Detección de secretos" 1
else
    report_check "Detección de secretos" 0
fi

# ==============================================================================
# 3. PYTHON LINTING (flake8)
# ==============================================================================
echo -e "\n${YELLOW}[3/7]${NC} 🐍 Linting Python (flake8)..."

if flake8 . \
    --count \
    --select=E9,F63,F7,F82 \
    --exclude=.venv,venv,.git,__pycache__,.pytest_cache \
    --show-source \
    --statistics \
    &> /tmp/flake8-critical.log; then
    report_check "Flake8 (errores críticos)" 0
else
    cat /tmp/flake8-critical.log
    report_check "Flake8 (errores críticos)" 1
fi

# Warnings no bloquean
flake8 . \
    --count \
    --max-complexity=10 \
    --max-line-length=127 \
    --exclude=.venv,venv,.git,__pycache__,.pytest_cache \
    --exit-zero \
    --statistics \
    > /tmp/flake8-warnings.log 2>&1

WARNING_COUNT=$(grep -c "^" /tmp/flake8-warnings.log || echo 0)
if [[ $WARNING_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC}  $WARNING_COUNT warnings de estilo (no bloquean)"
fi

# ==============================================================================
# 4. CODE FORMATTING (black)
# ==============================================================================
echo -e "\n${YELLOW}[4/7]${NC} 🎨 Verificando formato (black)..."

if [[ "$FIX_MODE" == true ]]; then
    black . --exclude='/(\.venv|venv|\.git|__pycache__|\.pytest_cache)/' &> /dev/null
    report_check "Black (auto-formateado)" 0
else
    if black --check --diff . --exclude='/(\.venv|venv|\.git|__pycache__|\.pytest_cache)/' &> /tmp/black.log; then
        report_check "Black (formato)" 0
    else
        echo -e "${YELLOW}💡 Ejecuta con --fix para auto-formatear${NC}"
        report_check "Black (formato)" 1
    fi
fi

# ==============================================================================
# 5. SECURITY CHECK (bandit)
# ==============================================================================
echo -e "\n${YELLOW}[5/7]${NC} 🛡️  Análisis de seguridad (bandit)..."

if bandit -r docker/ agent-ooda/ -ll -f text 2>/dev/null > /tmp/bandit.log; then
    report_check "Bandit (seguridad Python)" 0
else
    ISSUES=$(grep -c "Issue:" /tmp/bandit.log || echo 0)
    if [[ $ISSUES -gt 0 ]]; then
        echo -e "${YELLOW}⚠${NC}  $ISSUES problemas de seguridad encontrados:"
        cat /tmp/bandit.log
        report_check "Bandit (seguridad Python)" 1
    else
        report_check "Bandit (seguridad Python)" 0
    fi
fi

# ==============================================================================
# 6. DEPENDENCY SCANNING (safety)
# ==============================================================================
echo -e "\n${YELLOW}[6/7]${NC} 📦 Escaneando dependencias vulnerables..."

VULN_FOUND=false

# Kali deps
if [[ -f "docker/kali/requirements.txt" ]]; then
    if safety check -r docker/kali/requirements.txt --json > /tmp/safety-kali.json 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} Kali dependencies OK"
    else
        VULNS=$(jq '. | length' /tmp/safety-kali.json 2>/dev/null || echo 0)
        if [[ $VULNS -gt 0 ]]; then
            echo -e "${RED}  ✗${NC} $VULNS vulnerabilidades en Kali dependencies"
            VULN_FOUND=true
        fi
    fi
fi

# MCP deps
if [[ -f "docker/mcp/requirements.txt" ]]; then
    if safety check -r docker/mcp/requirements.txt --json > /tmp/safety-mcp.json 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} MCP dependencies OK"
    else
        VULNS=$(jq '. | length' /tmp/safety-mcp.json 2>/dev/null || echo 0)
        if [[ $VULNS -gt 0 ]]; then
            echo -e "${RED}  ✗${NC} $VULNS vulnerabilidades en MCP dependencies"
            VULN_FOUND=true
        fi
    fi
fi

if [[ "$VULN_FOUND" == true ]]; then
    report_check "Escaneo de dependencias" 1
else
    report_check "Escaneo de dependencias" 0
fi

# ==============================================================================
# 7. DOCKER LINTING (hadolint si está disponible)
# ==============================================================================
echo -e "\n${YELLOW}[7/7]${NC} 🐳 Verificando Dockerfiles..."

if command -v hadolint &> /dev/null; then
    DOCKER_ERRORS=0
    
    if hadolint docker/kali/Dockerfile 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} Kali Dockerfile OK"
    else
        echo -e "${RED}  ✗${NC} Issues en Kali Dockerfile"
        DOCKER_ERRORS=1
    fi
    
    if hadolint docker/mcp/Dockerfile 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} MCP Dockerfile OK"
    else
        echo -e "${RED}  ✗${NC} Issues en MCP Dockerfile"
        DOCKER_ERRORS=1
    fi
    
    report_check "Dockerfile linting" $DOCKER_ERRORS
else
    echo -e "${YELLOW}⚠${NC}  hadolint no instalado (opcional)"
    echo "   Instalar: brew install hadolint (macOS) o docker run --rm -i hadolint/hadolint"
fi

# ==============================================================================
# RESUMEN FINAL
# ==============================================================================
echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                        RESUMEN FINAL                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

PASSED=$((TOTAL_CHECKS - FAILED_CHECKS))
echo -e "Total de checks: ${BLUE}$TOTAL_CHECKS${NC}"
echo -e "Pasaron:         ${GREEN}$PASSED${NC}"
echo -e "Fallaron:        ${RED}$FAILED_CHECKS${NC}"
echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ TODOS LOS CHECKS PASARON - Listo para push                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ ALGUNOS CHECKS FALLARON - Corregir antes de push          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}💡 Sugerencias:${NC}"
    echo "   - Ejecutar con --fix para auto-formatear código"
    echo "   - Revisar los logs arriba para detalles específicos"
    echo "   - Si necesitas saltarte checks: git commit --no-verify"
    echo ""
    exit 1
fi
