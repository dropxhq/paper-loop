## 1. 项目基础结构

- [x] 1.1 创建 `backend/` 目录，初始化 Python 项目（`pyproject.toml` 或 `requirements.txt`）
- [x] 1.2 安装依赖：`fastapi`、`uvicorn`、`httpx`、`beautifulsoup4`、`pymupdf`、`spacy`、`anthropic`
- [x] 1.3 下载 spaCy 模型：`python -m spacy download en_core_web_sm`
- [x] 1.4 创建 FastAPI 应用入口 `backend/main.py`，添加健康检查接口 `GET /health`
- [x] 1.5 删除 iOS 模板占位代码：移除 `Item.swift`，清空 `ContentView.swift`

## 2. SwiftData 数据模型

- [x] 2.1 创建 `Models/Paper.swift`：`@Model` 定义 `Paper`（id, arxivId, title, abstract, htmlURL, pdfURL, importedAt）
- [x] 2.2 创建 `Models/Card.swift`：`@Model` 定义 `Card`（id, term, type, sourceSentence, contextBefore, contextAfter, zhHint, valueScore, anchor, paper 关联）
- [x] 2.3 创建 `Models/AnchorData.swift`：`Codable` enum，区分 `.html(elementId, htmlURL)` 和 `.pdf(page, bbox)`
- [x] 2.4 创建 `Models/ReviewLog.swift`：`@Model` 定义复习记录（id, card 关联, rating, reviewedAt）
- [x] 2.5 更新 `paper_loopApp.swift`：将 Schema 替换为新模型，移除 `Item.self`

## 3. iOS Tab Bar 导航骨架

- [x] 3.1 创建 `Views/ImportView.swift`：导入页占位（Tab 1）
- [x] 3.2 创建 `Views/ReviewView.swift`：复习页占位（Tab 2）
- [x] 3.3 创建 `Views/VocabView.swift`：词表页占位（Tab 3）
- [x] 3.4 创建 `Views/ProfileView.swift`：我的页占位（Tab 4）
- [x] 3.5 更新 `ContentView.swift`：替换为 `TabView`，接入 4 个 tab，图标和标题对齐设计规范

## 4. 后端导入管道 — paper-import

- [x] 4.1 创建 `backend/services/arxiv.py`：实现 `extract_paper_id(url)` 支持 abs/pdf 链接格式
- [x] 4.2 实现 `fetch_html(paper_id)` → 请求 `arxiv.org/html/{id}`，返回 BeautifulSoup 对象或 None
- [x] 4.3 实现 `parse_html_paragraphs(soup)` → 提取 `<section>` / `<p>` 元素，返回 `[{text, element_id, section_title}]`
- [x] 4.4 创建 `backend/services/pdf_parser.py`：实现 `download_pdf(paper_id)` + `parse_pdf_paragraphs(pdf_bytes)` → `[{text, page, bbox}]`
- [x] 4.5 创建 `POST /import` 接口：接收 `{url}`，返回 `{jobId, status: "processing"}`
- [x] 4.6 实现异步任务处理（`asyncio.create_task` 或 `BackgroundTasks`），完成后将结果写入内存/简单缓存
- [x] 4.7 创建 `GET /import/{jobId}` 状态轮询接口：返回 `{status, paper?, cards?}`

## 5. 后端抽词管道 — card-generation

- [x] 5.1 创建 `backend/services/extractor.py`：实现规则候选抽取（spaCy NER + RAKE + AWL 词表过滤）
- [x] 5.2 创建 `backend/prompts/extract.py`：维护中文 Claude Haiku 提示词（系统提示 + 用户消息模板）
- [x] 5.3 实现 `backend/services/llm_filter.py`：将候选列表分批发给 Claude Haiku，解析返回 JSON
- [x] 5.4 实现卡片去重归并逻辑：相同词根/词条合并，累计 `occurrenceCount`
- [x] 5.5 组装最终卡片结构，附加 anchor 数据（来自 HTML element_id 或 PDF page+bbox）

## 6. iOS 导入页实现

- [x] 6.1 实现 `ImportView`：arXiv URL 输入框 + "导入"按钮
- [x] 6.2 创建 `Services/ImportService.swift`：封装 `POST /import` 和轮询 `GET /import/{jobId}` 请求
- [x] 6.3 实现导入进度状态展示（解析中 → 生成卡片中 → 完成 / 失败）
- [x] 6.4 导入成功后将 Paper 和 Cards 存入 SwiftData，跳转到复习页

## 7. iOS 复习页实现 — review-loop

- [x] 7.1 实现 `ReviewView`：查询 `nextReviewAt ≤ now` 的卡片队列
- [x] 7.2 实现卡片正面展示（词/术语/句 + 播放按钮）
- [x] 7.3 实现"显示答案"交互：翻转动画 + 展示 zhHint、来源信息
- [x] 7.4 实现四档反馈按钮（不认识/模糊/认识/已掌握）+ SM-2 调度计算
- [x] 7.5 创建 `Services/ReviewScheduler.swift`：SM-2 算法实现（interval、easeFactor 更新）
- [x] 7.6 接入 AVSpeechSynthesizer：实现单词发音和整句朗读

## 8. 回链跳转实现 — source-backlink

- [x] 8.1 创建 `Views/SourceDetailView.swift`：展示来源论文、章节、原句（高亮）、前后上下文
- [x] 8.2 创建 `Views/HTMLReaderView.swift`：WKWebView 封装，支持加载 arXiv HTML 并注入 JS 滚动 + CSS 高亮
- [x] 8.3 创建 `Views/PDFReaderView.swift`：PDFKit PDFView 封装，支持 `findString` 定位和 PDFAnnotation 高亮
- [x] 8.4 实现 PDF 本地缓存（`FileManager` 存储到 Caches 目录）
- [x] 8.5 在 `ReviewView` 中接入"回到原文"入口，根据 anchor 类型路由到 HTML 或 PDF reader
