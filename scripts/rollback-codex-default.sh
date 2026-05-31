#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "[codex-deepseek] $*"; }
ok()   { echo -e "[codex-deepseek] ${GREEN}$*${NC}"; }
warn() { echo -e "[codex-deepseek] ${YELLOW}$*${NC}"; }

CODEX_CONFIG="${HOME}/.codex/config.toml"
CODEX_BACKUP="${HOME}/.codex/config.toml.codex_default_backup"

# Restore config
if [ -f "$CODEX_BACKUP" ]; then
    cp "$CODEX_BACKUP" "$CODEX_CONFIG"
    ok "config.toml restored"
else
    warn "No backup found"
fi

# Clear env
systemctl --user unset-environment DEEPSEEK_API_KEY 2>/dev/null || true
dbus-update-activation-environment --systemd DEEPSEEK_API_KEY 2>/dev/null || true
ok "Env cleared"

# Stop proxy
systemctl --user stop codex-proxy.service 2>/dev/null || true
ok "Proxy stopped"

# Restart Codex
pkill -f "codex-desktop" 2>/dev/null || true
sleep 2
nohup /usr/bin/codex-desktop > /dev/null 2>&1 &
sleep 2
ok "Rolled back to default. Codex Desktop restarted."
