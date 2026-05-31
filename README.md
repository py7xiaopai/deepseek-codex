# DeepSeek Codex

让 OpenAI Codex Desktop / CLI 无缝接入 DeepSeek 模型。

通过本地代理将 Codex 的 **Responses API** 协议翻译为 DeepSeek 的 **Chat Completions API**，支持流式响应、工具调用、推理模式。

## 工作原理

```
Codex Desktop / CLI                DeepSeek API
       │                                │
       │  POST /v1/responses            │
       │  (Responses API)               │
       └─────►  codex-proxy  ──────────►│
               协议转换                  │
               Responses ↔ Chat         │
               ◄────────────────────────┘
```

## 快速开始

### 前置条件

- Node.js >= 18
- Codex Desktop 或 Codex CLI（v0.81+）
- DeepSeek API Key（[获取地址](https://platform.deepseek.com/api_keys)）

### 一键安装

```bash
git clone https://github.com/py7xiaopai/deepseek-codex.git
cd deepseek-codex
./install.sh
```

安装脚本会自动完成：
1. 安装 `@roson_liu/codex-proxy` 代理
2. 配置 systemd 开机自启
3. 创建 Codex DeepSeek 配置文件
4. 部署桌面 wrapper（自动注入 API Key 环境变量）

### 配置 API Key

编辑 `~/.config/codex-deepseek-switch/env`：

```bash
export DEEPSEEK_API_KEY=sk-your-deepseek-api-key
```

### 启动

```bash
# 切换到 DeepSeek 模式
~/scripts/codex-deepseek/start-codex-deepseek.sh

# 恢复默认（使用 OpenAI 模型）
~/scripts/codex-deepseek/rollback-codex-default.sh
```

## 模型选择

Codex Desktop 输入框下方的模型选择器会显示两个选项：

| 模型 | 说明 |
|------|------|
| `deepseek-v4-flash` | 快速推理，日常编码 |
| `deepseek-v4-pro` | 强推理能力，复杂任务 |

## 命令参考

```bash
# 代理状态
systemctl --user status codex-proxy

# 重启代理
systemctl --user restart codex-proxy

# 查看代理日志
journalctl --user -u codex-proxy -f

# 健康检查
curl http://127.0.0.1:8001/v1/models
```

## 项目结构

```
deepseek-codex/
├── install.sh                     # 一键安装
├── scripts/
│   ├── start-codex-deepseek.sh    # 切换到 DeepSeek
│   └── rollback-codex-default.sh  # 恢复默认
├── systemd/
│   └── codex-proxy.service        # 开机自启
├── desktop/
│   └── codex-desktop-deepseek     # 桌面 wrapper
└── proxy/
    └── config.yaml.template       # 代理配置模板
```

## 依赖

- [@roson_liu/codex-proxy](https://www.npmjs.com/package/@roson_liu/codex-proxy) — Responses API → Chat Completions 协议转换代理
- [Codex CLI](https://github.com/openai/codex) — OpenAI Codex 命令行工具

## 致谢

- 代理核心基于 [@roson_liu/codex-proxy](https://www.npmjs.com/package/@roson_liu/codex-proxy)
- 灵感来自 [CoDeepSeedeX](https://github.com/Awenforever/CoDeepSeedeX)

## License

MIT
