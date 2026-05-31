#!/bin/bash
# ============================================================================
# deepseek-codex install script
# ============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[deepseek-codex]${NC} $*"; }
warn()  { echo -e "${YELLOW}[deepseek-codex]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info "Installing DeepSeek Codex..."

# 1. Install proxy dependency
info "Installing @roson_liu/codex-proxy..."
if ! command -v codex-proxy &>/dev/null; then
    npm install -g @roson_liu/codex-proxy
fi
info "codex-proxy ready"

# 2. Apply optimizations
info "Applying proxy optimizations..."
bash "$SCRIPT_DIR/scripts/patch-proxy.sh"

# 3. Create config directories
mkdir -p ~/.config/codex-deepseek-switch
mkdir -p ~/.codex-proxy

# 4. Set up proxy config
if [ ! -f ~/.codex-proxy/config.yaml ]; then
    cp "$SCRIPT_DIR/proxy/config.yaml.template" ~/.codex-proxy/config.yaml
    info "Proxy config created at ~/.codex-proxy/config.yaml"
    warn ">>> Edit this file with your DeepSeek API key!"
fi

# 5. Set up Codex switch env
if [ ! -f ~/.config/codex-deepseek-switch/env ]; then
    cat > ~/.config/codex-deepseek-switch/env << 'ENVEOF'
# DeepSeek API Key — 唯一的配置入口
# 获取地址: https://platform.deepseek.com/api_keys

export DEEPSEEK_API_KEY=sk-your-deepseek-api-key-here
ENVEOF
    chmod 600 ~/.config/codex-deepseek-switch/env
    info "API key file created at ~/.config/codex-deepseek-switch/env"
    warn ">>> Edit this file with your DeepSeek API key!"
fi

# 6. Copy scripts
mkdir -p ~/scripts/codex-deepseek
cp "$SCRIPT_DIR/scripts/"* ~/scripts/codex-deepseek/
chmod +x ~/scripts/codex-deepseek/*.sh ~/scripts/codex-deepseek/deepseek-codex
info "Scripts installed to ~/scripts/codex-deepseek/"

# 7. Symlink management tool
mkdir -p ~/.local/bin
ln -sf ~/scripts/codex-deepseek/deepseek-codex ~/.local/bin/deepseek-codex
info "deepseek-codex command installed"

# 8. Install desktop wrapper
cp "$SCRIPT_DIR/desktop/codex-desktop-deepseek" ~/.local/bin/
chmod +x ~/.local/bin/codex-desktop-deepseek
info "Desktop wrapper installed"

# 9. Install desktop entry
mkdir -p ~/.local/share/applications
if [ -f /usr/share/applications/codex-desktop.desktop ]; then
    sed "s|/usr/bin/codex-desktop|$HOME/.local/bin/codex-desktop-deepseek|g" \
        /usr/share/applications/codex-desktop.desktop \
        > ~/.local/share/applications/codex-desktop.desktop
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    info "Desktop entry installed"
fi

# 10. Install systemd service
mkdir -p ~/.config/systemd/user
sed "s|%HOME%|$HOME|g" "$SCRIPT_DIR/systemd/codex-proxy.service" \
    > ~/.config/systemd/user/codex-proxy.service
systemctl --user daemon-reload
systemctl --user enable codex-proxy.service
info "Systemd service installed (auto-start on login)"

# 11. Start proxy
systemctl --user restart codex-proxy.service
sleep 2
if curl -sS http://127.0.0.1:8001/v1/models >/dev/null 2>&1; then
    info "Proxy is running on http://127.0.0.1:8001"
fi

echo ""
info "========================================"
info "  DeepSeek Codex 安装完成!"
info "========================================"
echo ""
info "Manage with:"
info "  deepseek-codex status              健康检查"
info "  deepseek-codex update-key <key>    更换 API Key"
info "  deepseek-codex patch               重新应用代理补丁"
echo ""
info "Switch to DeepSeek:  ~/scripts/codex-deepseek/start-codex-deepseek.sh"
info "Rollback to default: ~/scripts/codex-deepseek/rollback-codex-default.sh"
echo ""
