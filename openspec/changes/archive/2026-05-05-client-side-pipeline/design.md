## Context

当前 PaperLoop 依赖本地运行的 Python 后端（FastAPI），iOS app 通过 HTTP 轮询 `localhost:8000` 来导入论文、生成词卡。后端使用 spacy/NLTK 做候选词提取，再通过 LLM 过滤。这导致：App 无法独立分发（用户需要手动启动后端服务）、有服务器运维成本，且无法上架 App Store。

目标架构：iOS app 直接调用 arXiv 公开 API 和用户自备的 LLM API，完全消除服务器依赖。

## Goals / Non-Goals

**Goals:**
- iOS app 独立运行，无需任何服务器进程
- 用户提供 OpenAI-compatible API Key（默认指向 DashScope + deepseek-v4-flash）
- 支持自定义 LLM baseURL（满足高级用户接入不同服务商）
- 保持现有 SwiftData 数据模型不变
- 保持现有 TTS 功能不变（DashScope 固定 endpoint）

**Non-Goals:**
- 离线完全可用（论文抓取和 LLM 调用仍需网络）
- 支持非 arXiv 论文（范围保持不变）
- 多端数据同步（iCloud/服务器）
- 批量导入（单次一篇）

## Decisions

### D1：用纯 LLM 替代 NLP 候选词提取

**选择**：舍弃 spacy/NLTK 两步流程，改为单步 LLM prompt——直接从段落中提取词汇、过滤低价值词、生成中文释义。

**理由**：
- iOS 不适合内嵌 40MB+ NLP 模型
- LLM 有完整上下文，提取质量不低于规则系统
- 代码大幅简化（两个服务 → 一个 prompt）

**备选考虑**：Apple NaturalLanguage 框架粗筛 + LLM 精过滤 → 复杂度增加，节省 token 有限，放弃。

---

### D2：HTML 优先，PDFKit 备选

**选择**：优先抓取 `arxiv.org/html/<id>`（用 SwiftSoup 解析），失败时下载 PDF 用 PDFKit 提取文字。

**理由**：
- arXiv HTML 版本覆盖近年论文（2021 年后 >80%）
- HTML 有 element ID，支持精确回链锚点
- PDFKit 对双栏 PDF 文字顺序可能错乱，但作为 fallback 可接受

**备选考虑**：PyMuPDF → 不可在 iOS 上直接使用。

---

### D3：API Key 存 Keychain，baseURL 存 UserDefaults

**选择**：API Key 用 `Security.framework` 存入 Keychain；baseURL 和 model 名称用 `@AppStorage`（UserDefaults）存储。

**理由**：
- Key 是敏感凭据，必须用 Keychain（不能明文存 UserDefaults/文件）
- baseURL/model 不敏感，AppStorage 简单方便

---

### D4：TTS API Key 与 LLM API Key 分离存储，但 UI 提示共用

**选择**：TTS Key 和 LLM Key 是独立的 Keychain 条目，但 ProfileView 提示"DashScope 用户只需填写一次，两处通用"。

**理由**：
- TTS 固定 DashScope endpoint，LLM 可能用其他服务商
- 分离存储允许用户用不同 key
- UI hint 降低 DashScope 用户的配置负担

---

### D5：LLM 调用按段落分批（每批 ≤30 段）

**选择**：将论文段落分成 ≤30 段一批，并发调用 LLM，合并结果。

**理由**：
- 避免单次超过 context window 或 token limit
- 并发提高速度（iOS `async/await` 天然支持）
- 每批独立，单批失败不影响其他批次

---

### D6：ImportService 改为本地 pipeline，移除 backend HTTP 调用

**选择**：`ImportService.swift` 重写为本地 async 编排器，直接调用 `ArXivFetchService` 和 `CardPipeline`，通过 `@MainActor` 回调更新 ImportView 状态。

**理由**：
- 现有 `ImportState` 枚举和 UI 流程完全可复用
- 避免引入新的状态管理层

## Risks / Trade-offs

- **PDFKit 双栏乱序** → arXiv HTML 覆盖大多数论文，PDF 是 fallback，乱序影响可接受；未来可加简单的列检测启发式算法改善
- **LLM 调用失败** → 每批独立错误处理，失败批次可提示用户重试；不阻塞已成功批次的卡片
- **Token 消耗不可预期** → 在 UI 中展示"正在生成…（第 x/y 批）"进度；未来可加 token 统计
- **API Key 配置摩擦** → 首次导入前检测 Key 是否存在，若缺失直接跳转到设置页（而非静默失败）
- **SwiftSoup 解析 arXiv HTML 结构变化** → arXiv HTML 格式相对稳定；抓取失败自动 fallback 到 PDF

## Migration Plan

1. 新建 `Services/ArXivFetchService.swift`、`Services/LLMService.swift`、`Services/CardPipeline.swift`
2. 重写 `Services/ImportService.swift`
3. 修改 `Views/ProfileView.swift` 新增 LLM 设置 UI
4. 在 Xcode 项目中添加 SwiftSoup SPM 依赖
5. 验证现有 SwiftData 数据（Card、Paper）schema 无需迁移
6. 删除 `backend/` 目录

**回滚**：删除 `backend/` 前先保留 git history，随时可恢复。iOS 侧修改均向后兼容（数据模型不变）。

## Open Questions

- SwiftSoup 是否能正确提取 arXiv HTML 的 section/paragraph 结构？需要实验验证（在实现 `arxiv-fetch` spec 时明确）
- 默认 LLM prompt 的输出 JSON schema 需精确定义（在 `llm-card-generation` spec 中固化）
