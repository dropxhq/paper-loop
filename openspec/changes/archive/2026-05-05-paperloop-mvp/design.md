## Context

iOS 应用已初始化（SwiftUI + SwiftData 模板）。后端尚未存在。核心挑战是：PDF/HTML 内容提取、文本位置锚定（回链依赖）、LLM 抽词质量，三者必须在架构层面协调一致。

## Goals / Non-Goals

**Goals:**
- 后端能处理 arXiv 链接并返回可直接存入 SwiftData 的卡片结构
- iOS 能展示卡片并完成复习交互（四档反馈 + SM-2 调度）
- 回链能跳转到原文并定位高亮

**Non-Goals:**
- 云同步、账号体系
- 扫描版 PDF / 非 arXiv 来源
- iPad 布局
- 离线抽词（MVP 阶段依赖后端）

## Decisions

### D1：内容提取路径 — HTML 优先 + PDF 兜底

arXiv 自 2023 年底提供基于 LaTeXML 的 HTML 版本（`arxiv.org/html/{id}`），覆盖率约 70–80%。HTML 版提供语义段落 ID（如 `S2.p1`），可直接作为回链 anchor，无需坐标计算。

- **HTML 路径**：`arxiv.org/html/{id}` → BeautifulSoup 解析 `<section>` / `<p>` → 保存 `element_id`
- **PDF 兜底**：下载 PDF → PyMuPDF `get_text("dict")` → 保存 `{page, bbox}`

放弃 Docling/Nougat：Docling 处理速度慢（10–30s/页），Nougat 丢失位置信息，均不适合 MVP。

### D2：抽词管道 — 两阶段（规则候选 → LLM 筛选）

单次 LLM 调用处理全文质量有限且 token 成本高；纯规则难以识别语境价值。两阶段分工：

```
段落文本
  │
  ▼
Stage 1 规则候选（本地，< 1s）
  • spaCy en_core_web_sm — NER 识别专有名词短语
  • RAKE — 多词术语候选
  • AWL 过滤 — 保留学术高频词
  • 正则 — 定义句/结果句/贡献句模式
  │
  ▼  ~50–150 候选/篇
Stage 2 Claude Haiku（1 次 API call，~$0.005/篇）
  • 输入：候选列表 + 原句上下文
  • 输出：JSON — type(word|phrase|sentence), value(1-5), keep, zh_hint
```

中文提示词维护在 `backend/prompts/extract.py`。

### D3：Anchor 数据结构 — 统一 union type

```python
# HTML anchor
{ "type": "html", "element_id": "S2.p3", "paper_html_url": "..." }

# PDF anchor
{ "type": "pdf", "page": 3, "bbox": [x0, y0, x1, y1] }
```

iOS 侧对应 SwiftData 枚举：
```swift
enum AnchorData: Codable {
    case html(elementId: String, htmlURL: URL)
    case pdf(page: Int, bbox: CGRect)
}
```

### D4：回链跳转实现

- **HTML anchor**：`WKWebView` 加载 `arxiv.org/html/{id}`，加载完成后注入 JS：
  `document.getElementById(elementId).scrollIntoView()` + CSS highlight class
- **PDF anchor**：`PDFKit` 加载下载缓存的 PDF，`PDFDocument.findString(sourceText)` 
  → `PDFView.go(to: PDFSelection)` + `PDFAnnotation(.highlight)`
  
  > 用文本搜索而非坐标定位：坐标需精确对齐，而 `findString` 对 arXiv text-layer PDF 可靠度更高。

### D5：本地开发网络 — HTTP localhost

iOS Simulator 可访问 `http://localhost:8000`，无需 HTTPS。真机调试需要同局域网 IP 或 ngrok。MVP 阶段只做 Simulator，后续再处理。

### D6：SwiftData Schema

```
Paper
  id, arxivId, title, abstract, htmlURL, pdfURL, importedAt

Card
  id, term, type(word|phrase|sentence), sourceSentence,
  contextBefore, contextAfter, zhHint, valueScore,
  anchor(AnchorData), paper(→Paper),
  nextReviewAt, easeFactor, interval, repetitions

ReviewLog
  id, card(→Card), rating(1-4), reviewedAt
```

## Risks / Trade-offs

- **arXiv HTML 覆盖率不足** → 兜底 PDF 路径覆盖；用户见到"使用 PDF 解析"提示
- **PyMuPDF 多栏顺序混乱** → arXiv 论文多为单栏或双栏，双栏时按 x 坐标分左右列再排序
- **Claude API 延迟** → 后端异步处理，iOS 展示进度状态（解析中 → 生成卡片中 → 完成）
- **spaCy 模型体积**（`en_core_web_sm` ~12MB）→ 后端启动时一次性加载，不影响请求延迟
- **findString 匹配失败**（PDF 文字层损坏）→ 降级到仅跳转页码，不高亮

## Open Questions

- arXiv HTML 的 `<p id>` 格式是否在不同论文间一致？需要用几篇真实论文验证 LaTeXML 输出
- SM-2 初始参数（ease factor = 2.5，initial interval = 1d）是否需要可配置？MVP 阶段先硬编码
