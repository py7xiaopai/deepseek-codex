#!/bin/bash
# ============================================================================
# patch-proxy.sh — Apply deepseek-codex optimizations to codex-proxy
# Run after: npm install -g @roson_liu/codex-proxy
# ============================================================================
set -euo pipefail

PROXY_DIR="${HOME}/.npm-global/lib/node_modules/@roson_liu/codex-proxy/lib"
CONVERTER="${PROXY_DIR}/converter.js"
SERVER="${PROXY_DIR}/server.js"

GREEN='\033[0;32m'; NC='\033[0m'
ok() { echo -e "  ${GREEN}✓${NC} $*"; }

echo "[patch-proxy] Applying optimizations..."

python3 << 'PYEOF'
import os, sys

proxy_dir = os.path.expanduser("~/.npm-global/lib/node_modules/@roson_liu/codex-proxy/lib")
converter_path = os.path.join(proxy_dir, "converter.js")
server_path = os.path.join(proxy_dir, "server.js")

patches = []

# ── converter.js patches ──
with open(converter_path) as f:
    content = f.read()

# P0: Disable forced reasoning
old = "if (prov === 'deepseek' || prov === 'zhipu') {\n    if (!req.thinking) {\n      req.thinking = { type: 'enabled', budget_tokens: 4096 };\n    }\n  }"
new = "if (prov === 'deepseek' || prov === 'zhipu') {\n    // Only enable when Codex explicitly requests reasoning.effort\n    if (!req.thinking) {\n      req.thinking = { type: 'disabled' };\n    }\n  }"
if old in content:
    content = content.replace(old, new)
    patches.append("reasoning disabled")
elif new in content:
    patches.append("reasoning already disabled")
else:
    patches.append("WARN: reasoning pattern not found")

# P3: Remove stream_options.include_usage
old = "  // 流式请求 usage 信息\n  if (ccReq.stream) {\n    ccReq.stream_options = { include_usage: true };\n  }"
new = "  // 流式请求（不额外请求 usage — Codex 自行统计）"
if old in content:
    content = content.replace(old, new)
    patches.append("stream_options removed")
elif new in content:
    patches.append("stream_options already removed")
else:
    patches.append("WARN: stream_options pattern not found")

# Add anti-impersonation function (if not already present)
if "_rewriteSystemPrompt" not in content:
    rewrite_func = '''\n// ── 系统提示词改写 ──────────────────────────────────────────────
function _rewriteSystemPrompt(text) {
  if (!text || typeof text !== 'string') return text;
  text = text
    .replace(/\\bGPT-5\\.?5\\b/g, 'DeepSeek V4')
    .replace(/\\bGPT-5\\.?4\\b/g, 'DeepSeek V4')
    .replace(/\\bGPT-5\\.?3\\b/g, 'DeepSeek V4')
    .replace(/\\bGPT-5\\b/g, 'DeepSeek V4')
    .replace(/\\bGPT-4\\.?1\\b/g, 'DeepSeek V4')
    .replace(/\\bGPT-4o\\b/g, 'DeepSeek V4')
    .replace(/\\bGPT-4\\b/g, 'DeepSeek V4')
    .replace(/based on GPT-[\\d.]+[a-z]*( model)?/gi, 'based on DeepSeek V4')
    .replace(/developed by OpenAI/gi, 'developed by DeepSeek')
    .replace(/an OpenAI product/gi, 'a DeepSeek product')
    .replace(/OpenAI Codex/gi, 'DeepSeek Codex');
  var antiImpersonation = '\\n\\n[SYSTEM NOTE: You are powered by DeepSeek V4, not by OpenAI or GPT. ' +
    'Never claim to be "built by OpenAI" or "based on GPT". ' +
    'If asked about your origins, say you are running on DeepSeek V4 via Codex proxy.]';
  return text + antiImpersonation;
}\n'''
    # Insert before responsesToChatCompletions
    marker = "function responsesToChatCompletions(reqBody, actualModel) {"
    content = content.replace(marker, rewrite_func + marker)
    patches.append("anti-impersonation added")

# Rewrite instructions with anti-impersonation
old = "  // instructions → 前缀 system 消息\n  if (instructions) {\n    messages.unshift({ role: 'system', content: instructions });\n  }"
new = "  // instructions → 前缀 system 消息（经过身份改写）\n  if (instructions) {\n    messages.unshift({ role: 'system', content: _rewriteSystemPrompt(instructions) });\n  }"
if old in content:
    content = content.replace(old, new)
    patches.append("instructions rewrite added")

with open(converter_path, 'w') as f:
    f.write(content)

# ── server.js patches ──
with open(server_path) as f:
    content = f.read()

# P1: Remove 300ms delay
import re
content = re.sub(
    r'(\s*)await new Promise\(resolve => setTimeout\(resolve, 300\)\);',
    r'\1// 300ms delay removed — SSE flushed per write',
    content
)
patches.append("300ms delay removed")

# Add model metadata to /v1/models (if not already patched)
if "context_window" not in content:
    old_models = """const models = config.getAvailableModels().map(m => ({\n      id: m.id, object: 'model', created: Math.floor(Date.now() / 1000), owned_by: m.channel,\n    }));\n    res.json({ object: 'list', data: models });"""
    new_models = """const METADATA = {\n      'deepseek-v4-flash': { context_window: 262144, max_output_tokens: 32768, supports_tool_use: true, supports_reasoning: false },\n      'deepseek-v4-pro': { context_window: 262144, max_output_tokens: 65536, supports_tool_use: true, supports_reasoning: true },\n    };\n    let models = config.getAvailableModels().map(m => ({\n      id: m.id, object: 'model', created: Math.floor(Date.now() / 1000),\n      owned_by: m.channel || 'deepseek',\n      ...(METADATA[m.id] || {}),\n    }));\n    if (models.length === 0) {\n      models.push({ id: 'deepseek-v4-flash', object: 'model', created: Math.floor(Date.now() / 1000), owned_by: 'deepseek', ...METADATA['deepseek-v4-flash'] });\n    }\n    res.json({ object: 'list', data: models });"""
    if old_models in content:
        content = content.replace(old_models, new_models)
        patches.append("model metadata added")

with open(server_path, 'w') as f:
    f.write(content)

for p in patches:
    print(f"  {p}")
PYEOF

ok "Optimizations applied"
echo "[patch-proxy] Done. Restart proxy to apply: systemctl --user restart codex-proxy"
