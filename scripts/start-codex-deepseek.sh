#!/bin/bash
# ============================================================================
# start-codex-deepseek.sh — 将 Codex Desktop 切换到 DeepSeek 模式
# 使用 @roson_liu/codex-proxy 做 Responses API → Chat API 翻译
# ============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "[codex-deepseek] $*"; }
ok()   { echo -e "[codex-deepseek] ${GREEN}$*${NC}"; }
warn() { echo -e "[codex-deepseek] ${YELLOW}$*${NC}"; }

SWITCH_ENV="${HOME}/.config/codex-deepseek-switch/env"
CODEX_CONFIG="${HOME}/.codex/config.toml"
CODEX_BACKUP="${HOME}/.codex/config.toml.codex_default_backup"
PROXY_BIN="${HOME}/.npm-global/bin/codex-proxy"
PROXY_CONFIG="${HOME}/.codex-proxy/config.yaml"
PROXY_DIR="${HOME}/.codex-proxy"

# ── preflight ──
log "Checking prerequisites..."
source "$SWITCH_ENV"
if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo -e "${RED}DEEPSEEK_API_KEY not set in ${SWITCH_ENV}${NC}"
    exit 1
fi

# Ensure codex-proxy config is up-to-date
mkdir -p "$PROXY_DIR"
cat > "$PROXY_CONFIG" << EOF
server:
  port: 8001
  host: '127.0.0.1'
channels:
  deepseek:
    name: deepseek
    base_url: https://api.deepseek.com
    api_key: ${DEEPSEEK_API_KEY}
    models:
      - deepseek-v4-flash
      - deepseek-v4-pro
model_routing:
  deepseek-v4-flash:
    channel: deepseek
    model: deepseek-v4-flash
  deepseek-v4-pro:
    channel: deepseek
    model: deepseek-v4-pro
  _default:
    channel: deepseek
    model: deepseek-v4-pro
log_level: INFO
EOF
chmod 600 "$PROXY_CONFIG"
ok "Proxy config updated"

# ── Codex config.toml ──
if [ -f "$CODEX_CONFIG" ] && [ ! -f "$CODEX_BACKUP" ]; then
    cp "$CODEX_CONFIG" "$CODEX_BACKUP"
    ok "Config backed up"
fi

python3 << 'PYEOF'
import os
config_path = os.path.expanduser("~/.codex/config.toml")
lines = []
if os.path.exists(config_path):
    with open(config_path) as f:
        lines = [l.rstrip() for l in f.readlines()]

def upsert(lines, key, value):
    new_line = f'{key} = "{value}"'
    for i, line in enumerate(lines):
        if line.strip().startswith(f"{key} =") or line.strip().startswith(f"{key}="):
            lines[i] = new_line
            return
    lines.insert(0, new_line)

def ensure_section(lines, name, entries):
    header = f"[{name}]"
    try: idx = lines.index(header)
    except ValueError: idx = -1
    block = [header] + [f'{k} = "{v}"' for k,v in entries.items()]
    if idx >= 0:
        end = idx + 1
        while end < len(lines) and lines[end].strip() and not lines[end].strip().startswith("["):
            end += 1
        lines[idx:end] = block
    else:
        lines.append("")
        lines.extend(block)

upsert(lines, "model", "deepseek-v4-pro")
upsert(lines, "model_provider", "deepseek")
ensure_section(lines, "model_providers.deepseek", {
    "name": "DeepSeek (via codex-proxy)",
    "base_url": "http://127.0.0.1:8001/v1",
    "env_key": "DEEPSEEK_API_KEY",
    "wire_api": "responses",
})
ensure_section(lines, "profiles.deepseek", {"model": "deepseek-v4-flash", "model_provider": "deepseek"})
ensure_section(lines, "profiles.deepseek-thinking", {"model": "deepseek-v4-pro", "model_provider": "deepseek"})

with open(config_path, "w") as f:
    f.write("\n".join(lines) + "\n")
print("[codex-deepseek] config.toml updated")
PYEOF
ok "config.toml updated"

# ── env vars ──
systemctl --user set-environment "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}" 2>/dev/null || true
dbus-update-activation-environment --systemd DEEPSEEK_API_KEY 2>/dev/null || true
ok "Environment injected"

# ── restart proxy via systemd ──
log "Restarting codex-proxy..."
systemctl --user restart codex-proxy.service 2>/dev/null || true
sleep 2
if curl -sS http://127.0.0.1:8001/v1/models >/dev/null 2>&1; then
    ok "codex-proxy running on :8001"
else
    warn "Proxy might not be ready — check: systemctl --user status codex-proxy"
fi

# ── restart Codex Desktop ──
log "Restarting Codex Desktop..."
pkill -f "^/usr/bin/codex-desktop|^/opt/codex-desktop/electron" 2>/dev/null || true
sleep 2
nohup /home/jckchen/.local/bin/codex-desktop-deepseek > /dev/null 2>&1 &
sleep 2
ok "DeepSeek mode enabled. Codex Desktop restarted."
echo ""
log "Commands:"
log "  Rollback: ~/scripts/codex-deepseek/rollback-codex-default.sh"
