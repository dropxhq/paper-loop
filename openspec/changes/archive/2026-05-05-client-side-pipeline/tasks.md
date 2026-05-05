## 1. 依赖与项目配置

- [x] 1.1 在 Xcode 中通过 Swift Package Manager 添加 SwiftSoup 依赖（`https://github.com/scinfu/SwiftSoup`）
- [x] 1.2 确认 `Info.plist` 的 ATS 配置允许访问 `arxiv.org`（HTTPS，无需额外配置）

## 2. Keychain 工具

- [x] 2.1 创建 `KeychainHelper.swift`，封装 `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete`，提供 `save(key:value:)`、`read(key:) -> String?`、`delete(key:)` 接口

## 3. LLM 服务

- [x] 3.1 创建 `Services/LLMService.swift`，实现 OpenAI-compatible `POST /chat/completions` 调用，从 `@AppStorage` 读取 baseURL（默认 `https://dashscope.aliyuncs.com/compatible-mode/v1`）和模型名（默认 `deepseek-v4-flash`），从 Keychain 读取 API Key
- [x] 3.2 在 `LLMService` 中实现 `chatCompletion(system:user:) async throws -> String`
- [x] 3.3 在 `LLMService` 中实现 API Key 缺失检测，Key 为空时抛出 `LLMError.missingAPIKey`

## 4. arXiv 抓取服务

- [x] 4.1 创建 `Services/ArXivFetchService.swift`，实现 `fetchMetadata(arxivId:) async throws -> PaperMeta`，解析 arXiv Atom XML 获取标题和摘要
- [x] 4.2 实现 `fetchHTMLParagraphs(arxivId:) async -> [Paragraph]?`，用 SwiftSoup 解析 `<section>`/`<h1-4>`/`<p>` 元素，每段附带 `elementId` 和 `section` 字段，文字长度 <30 的段落跳过
- [x] 4.3 实现 `fetchPDFParagraphs(arxivId:) async throws -> [Paragraph]`，用 URLSession 下载 PDF，PDFKit 按页提取文字，每段附带 `page` 字段；文字全空时抛出"扫描版不支持"错误

## 5. 卡片生成 Pipeline

- [x] 5.1 创建 `Services/CardPipeline.swift`，实现 `generateCards(paragraphs:paperContext:) async throws -> [CardData]`，将段落分批（≤30段/批），并发调用 `LLMService`
- [x] 5.2 在 `CardPipeline` 中实现 prompt 构造（system prompt 复用 `backend/src/prompts/extract.py` 中的提示语，翻译为对应 Swift 字符串常量）
- [x] 5.3 实现 JSON 解析逻辑：从 LLM 响应中提取 JSON 数组（处理 markdown code fence），过滤 `keep=false` 和 `value≤2` 的条目，失败批次返回空数组不抛出

## 6. ImportService 重写

- [x] 6.1 重写 `Services/ImportService.swift`，移除所有后端 HTTP 调用和 `baseURL = "http://localhost:8000"` 相关代码
- [x] 6.2 实现本地 pipeline 编排：`startImport(url:) async throws`，依次调用 ArXivFetchService（元数据 + HTML/PDF 段落）→ CardPipeline（LLM 生成）→ 返回 Paper + Cards 结构体
- [x] 6.3 在 `ImportView.performImport` 中适配新 `ImportService` 接口，状态流转：`parsing` → `generatingCards` → `done`（移除 `parsingPDF` 单独状态或保留均可）
- [x] 6.4 处理 `LLMError.missingAPIKey`：在 `ImportView` 捕获并展示引导文案"请先在「我的」中设置 API Key"

## 7. API Key 设置 UI

- [x] 7.1 在 `Views/ProfileView.swift` 中新增"AI 设置"card，包含：LLM API Key 输入框（`SecureField`，保存时写 Keychain）、baseURL 输入框（`TextField`，保存到 `@AppStorage`）、model 输入框（可选，默认值提示）
- [x] 7.2 在 LLM API Key 输入区域下方添加提示文字："DashScope 用户：语音朗读与卡片生成可使用同一 Key"
- [x] 7.3 实现 Key 掩码展示（读取时显示 `sk-xxx...xxx` 格式，不暴露完整 Key）

## 8. 清理

- [x] 8.1 删除 `backend/` 整个目录（确认 git history 中保留，可直接 `git rm -r backend/`）
- [x] 8.2 从 Xcode 项目中移除已不再使用的 `ImportService` 旧网络相关代码（`PaperResponse`、`CardResponse`、`ImportStatusResponse`、`StartImportResponse` 等 Decodable 结构体）

## 9. 测试验证

- [ ] 9.1 用有 HTML 版本的 arXiv 论文（如 `2310.06825`）完整走一遍导入流程，验证卡片生成
- [ ] 9.2 用仅有 PDF 的旧论文验证 PDFKit fallback 路径
- [ ] 9.3 在未设置 API Key 时验证导入被阻断，提示文案正确
- [ ] 9.4 在 ProfileView 验证 Key 保存/读取/掩码展示正确
