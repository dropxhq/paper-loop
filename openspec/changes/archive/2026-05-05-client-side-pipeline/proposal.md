## Why

当前架构依赖自建 Python 后端（FastAPI + spacy + NLTK + OpenAI），导致应用有服务器运维成本和单点故障风险。用户希望软件完全无服务器依赖，由用户提供自己的 LLM API Key，实现纯客户端离线可用（联网只调用 arXiv 和 LLM API）。

## What Changes

- **移除**整个 `backend/` Python 服务（FastAPI、spacy、NLTK、card_pipeline、extractor、llm_filter）
- **新增** iOS 原生 ArXiv 抓取服务（HTML 优先，PDF 备选，使用 URLSession + SwiftSoup + PDFKit）
- **新增** iOS 原生 LLM 卡片生成服务（OpenAI-compatible API，支持自定义 baseURL，单步 prompt 完成提取+过滤+翻译）
- **新增** API Key 设置 UI（ProfileView 中新增 LLM 设置 card，支持 Key + baseURL 配置，Keychain 存储）
- **修改** `ImportService.swift`：移除对本地后端的 HTTP 调用，改为直接调用新的本地服务
- **保留** TTS（DashScope 固定 endpoint，不开放自定义 baseURL）
- **保留** SwiftData 本地存储层（不变）

## Capabilities

### New Capabilities

- `arxiv-fetch`: 客户端直接从 arXiv 获取论文元数据（Atom XML）和正文（HTML/PDF），含段落提取逻辑
- `llm-card-generation`: 基于 OpenAI-compatible API 的卡片生成服务，支持自定义 baseURL 和 API Key，单步 prompt 完成候选词提取、过滤、中文释义
- `api-key-settings`: ProfileView 中的 LLM API 设置界面（Key + baseURL），使用 Keychain 安全存储

### Modified Capabilities

- `paper-import`: 导入流程从轮询远程 job 改为本地 async pipeline（arXiv 抓取 → 段落分割 → LLM 批量生成 → SwiftData 保存），进度状态仍通过已有 `ImportState` 枚举驱动

## Impact

- **删除**：`backend/` 整个目录（Python 项目、所有服务代码）
- **新增**：`Services/ArXivFetchService.swift`、`Services/LLMService.swift`、`Services/CardPipeline.swift`
- **修改**：`Services/ImportService.swift`（重写为本地 pipeline 编排）、`Views/ProfileView.swift`（新增 LLM 设置 card）、`Info.plist`（添加 NSAppTransportSecurity 或确认 HTTPS 足够）
- **新增依赖**：SwiftSoup（Swift Package，HTML 解析）；PDFKit（Apple 原生，无需新增）
- **API**：用户需提供 DashScope/OpenAI-compatible API Key；默认 baseURL 为 `https://dashscope.aliyuncs.com/compatible-mode/v1`，默认模型为 `deepseek-v4-flash`
