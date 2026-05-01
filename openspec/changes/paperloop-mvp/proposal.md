## Why

PaperLoop 尚无任何可运行代码。需要建立 iOS 应用骨架与 Python 后端服务的基础，使"导入 arXiv 论文 → 自动生成卡片 → 在 iPhone 上复习 → 回到原文"这条核心链路跑通。

## What Changes

- 新增 Python FastAPI 后端（`backend/`），提供论文导入管道：arXiv 链接解析 → HTML/PDF 内容提取 → 规则候选词抽取 → Claude Haiku 筛选分类 → 返回结构化卡片与 anchor 数据
- 新增 SwiftUI iOS 应用结构：Tab Bar 导航（导入、复习、词表、我的）+ SwiftData 数据模型（Paper、Card、Anchor）
- 移除 Xcode 模板占位代码（`Item.swift`、`ContentView.swift` 现有内容）

## Capabilities

### New Capabilities

- `paper-import`: 用户输入 arXiv 链接，后端提取正文内容并返回结构化论文数据（标题、摘要、段落列表、anchor 信息）
- `card-generation`: 后端从段落文本中自动生成词卡、术语卡、句卡，包含分类、价值评分和中文释义提示
- `review-loop`: iOS 端展示卡片、支持显示答案、四档记忆反馈（不认识 / 模糊 / 认识 / 已掌握），基于 SM-2 算法调度下次复习
- `source-backlink`: 每张卡片关联原文 anchor（HTML element ID 或 PDF page+bbox），支持在 WKWebView / PDFKit 中跳转并高亮原句

### Modified Capabilities

（无现有 spec）

## Impact

- 新增依赖：`pymupdf`、`spacy`、`anthropic` Python SDK、`fastapi`、`uvicorn`
- iOS 最低部署目标：iOS 17（SwiftData 要求）
- 本地开发：后端运行在 `localhost:8000`，iOS Simulator 通过 `http://localhost:8000` 访问
- 数据存储：iOS 端使用 SwiftData 本地持久化，MVP 阶段不涉及云同步
