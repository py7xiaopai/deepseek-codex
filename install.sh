#!/bin/bash
# ============================================================================
# deepseek-codex install script
# ============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
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

# 2. Create config directories
mkdir -p ~/.config/codex-deepseek-switch
mkdir -p ~/.codex-proxy

# 3. Set up proxy config (without API key — user fills in later)
if [ ! -f ~/.codex-proxy/config.yaml ]; then
    cp "$SCRIPT_DIR/proxy/config.yaml.template" ~/.codex-proxy/config.yaml
    info "Proxy config created at ~/.codex-proxy/config.yaml"
fi

# 4. Set up Codex switch env file
if [ ! -f ~/.config/codex-deepseek-switch/env ]; then
    cat > ~/.config/codex-deepseek-switch/env << 'ENVEOF'
# DeepSeek API Key — 唯一的配置入口
# 获取地址: https://platform.deepseek.com/api_keys

export DEEPSEEK_API_KEY=sk-your-deepseek-api-key-here
ENVEOF
    chmod 600 ~/.config/codex-deepseek-switch/env
    info "API key file created at ~/.config/codex-deepseek-switch/env"
    warn ">>> Please edit this file with your DeepSeek API key!"
fi

# 5. Copy scripts
mkdir -p ~/scripts/codex-deepseek
cp "$SCRIPT_DIR/scripts/start-codex-deepseek.sh" ~/scripts/codex-deepseek/
cp "$SCRIPT_DIR/scripts/rollback-codex-default.sh" ~/scripts/codex-deepseek/
chmod +x ~/scripts/codex-deepseek/*.sh
info "Scripts installed to ~/scripts/codex-deepseek/"

# 6. Install desktop wrapper
mkdir -p ~/.local/bin
cp "$SCRIPT_DIR/desktop/codex-desktop-deepseek" ~/.local/bin/
chmod +x ~/.local/bin/codex-desktop-deepseek
info "Desktop wrapper installed"

# 7. Install desktop entry
mkdir -p ~/.local/share/applications
if [ -f /usr/share/applications/codex-desktop.desktop ]; then
    sed "s|/usr/bin/codex-desktop|$HOME/.local/bin/codex-desktop-deepseek|g" \
        /usr/share/applications/codex-desktop.desktop \
        > ~/.local/share/applications/codex-desktop.desktop
    update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    info "Desktop entry installed (Codex will auto-inject API key)"
fi

# 8. Install systemd service
mkdir -p ~/.config/systemd/user
cp "$SCRIPT_DIR/systemd/codex-proxy.service" ~/.config/systemd/user/
sed -i "s|%HOME%|$HOME|g" ~/.config/systemd/user/codex-proxy.service
systemctl --user daemon-reload
systemctl --user enable codex-proxy.service
info "Systemd service installed (auto-start on login)"

# 9. Start proxy
systemctl --user restart codex-proxy.service
sleep 2
if curl -sS http://127.0.0.1:8001/v1/models >/dev/null 2>&1; then
    info "Proxy is running on http://127.0.0.1:8001"
else
    warn "Proxy may not be ready. Check: systemctl --user status codex-proxy"
fi

echo ""
info "========================================"
info "  DeepSeek Codex 安装完成!"
info "========================================"
echo ""
info "下一步:"
info "  1. 编辑 ~/.config/codex-deepseek-switch/env 填入 DeepSeek API Key"
info "  2. 运行 ~/scripts/codex-deepseek/start-codex-deepseek.sh 切换模式"
echo ""
