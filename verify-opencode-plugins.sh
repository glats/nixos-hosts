#!/usr/bin/env bash
# Verificar estado de plugins TUI de OpenCode

echo "=== Verificación de Plugins TUI de OpenCode ==="
echo

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONFIG_DIR="$HOME/.config/opencode"
TUI_JSON="$CONFIG_DIR/tui.json"
NODE_MODULES="$CONFIG_DIR/node_modules"

echo -e "${YELLOW}1. Verificando tui.json...${NC}"
if [ -f "$TUI_JSON" ]; then
    echo -e "${GREEN}✓${NC} tui.json existe"
    echo -e "${YELLOW}   Contenido:${NC}"
    cat "$TUI_JSON" | jq . 2>/dev/null || cat "$TUI_JSON"
    echo
    
    # Verificar si tiene la clave correcta "plugin"
    if cat "$TUI_JSON" | jq -e '.plugin' >/dev/null 2>&1; then
        PLUGIN_COUNT=$(cat "$TUI_JSON" | jq '.plugin | length')
        echo -e "${GREEN}✓${NC} Clave 'plugin' encontrada ($PLUGIN_COUNT plugins)"
    else
        echo -e "${RED}✗${NC} ERROR: No se encontró la clave 'plugin' en tui.json"
        echo -e "   ${YELLOW}Nota:${NC} Debe ser 'plugin' (singular), no 'plugins' (plural)"
    fi
else
    echo -e "${RED}✗${NC} tui.json NO existe en $TUI_JSON"
fi

echo
echo -e "${YELLOW}2. Verificando instalación npm...${NC}"
if [ -d "$NODE_MODULES" ]; then
    echo -e "${GREEN}✓${NC} node_modules existe"
    
    # Verificar plugins específicos
    echo
    echo -e "${YELLOW}   Plugins instalados:${NC}"
    
    if [ -d "$NODE_MODULES/opencode-subagent-statusline" ]; then
        VERSION=$(cat "$NODE_MODULES/opencode-subagent-statusline/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "desconocida")
        echo -e "   ${GREEN}✓${NC} opencode-subagent-statusline@$VERSION"
    else
        echo -e "   ${RED}✗${NC} opencode-subagent-statusline NO instalado"
    fi
    
    if [ -d "$NODE_MODULES/opencode-sdd-engram-manage" ]; then
        VERSION=$(cat "$NODE_MODULES/opencode-sdd-engram-manage/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "desconocida")
        echo -e "   ${GREEN}✓${NC} opencode-sdd-engram-manage@$VERSION"
    else
        echo -e "   ${RED}✗${NC} opencode-sdd-engram-manage NO instalado"
    fi
else
    echo -e "${RED}✗${NC} node_modules NO existe"
    echo -e "   ${YELLOW}Nota:${NC} Debes activar la configuración con 'home-manager switch' o reiniciar sesión"
fi

echo
echo -e "${YELLOW}3. Comandos para verificar en OpenCode:${NC}"
echo "   Cuando OpenCode esté corriendo, ejecuta:"
echo
echo "   ${GREEN}api.plugins.list()${NC}"
echo "      - Muestra todos los plugins instalados"
echo
echo "   ${GREEN}api.plugins.activate('opencode-subagent-statusline')${NC}"
echo "      - Activa el plugin de statusline"
echo
echo "   ${GREEN}api.plugins.activate('opencode-sdd-engram-manage')${NC}"
echo "      - Activa el plugin de SDD engram"
echo
echo -e "${YELLOW}4. Ubicación de archivos:${NC}"
echo "   tui.json:    $TUI_JSON"
echo "   node_modules: $NODE_MODULES"

echo
echo "=== Fin de verificación ==="
