# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**PaperLoop** — converts academic paper PDFs into reviewable flashcards (vocabulary, terminology, sentence patterns) with pronunciation, source linking, and spaced repetition. Target platform: iPhone-first MVP, focused on a learning loop for paper reading.

## Conventions

- Prompt text in this project is maintained in Chinese.

## Python Environment

- Python 依赖由 **uv** 管理。
- 运行 Python 脚本必须使用：`uv run --env-file .env <script>`

## iOS App (Swift / SwiftUI)

项目已有可构建的 SwiftUI MVP，入口：`paper-loop/paper-loop.xcodeproj`。

### 设计系统

所有设计 token 集中在 `paper-loop/paper-loop/Theme.swift`，与 `docs/paper_vocab_iphone_mvp_v2.html` 保持一致：

| Token | 值 | 用途 |
|---|---|---|
| `Theme.bg` | `#f6f2ea` 暖米色 | 全局背景 |
| `Theme.surface` | `#fffdfa` 暖白 | 卡片背景 |
| `Theme.surface2` | `#efe6da` | 列表行、输入框背景 |
| `Theme.primary` | `#0c6865` 深青绿 | 主色调、按钮、强调 |
| `Theme.primarySoft` | `#dce8e5` | 徽章/高亮背景 |
| `Theme.textPrimary` | `#201d18` | 主文本 |
| `Theme.textMuted` | `#6f675d` | 次要文本 |

**圆角**：卡片 r24、列表行 r18、按钮/输入框 r16。

**可复用组件**（定义在 `Theme.swift`）：
- `EyebrowBadge` — 青绿胶囊标签
- `SectionHeader` — 带 badge 的区块标题
- `MiniStatBox` — 数字统计格
- `PrimaryButtonStyle` — 全宽实心按钮
- `ChipButtonStyle(filled:)` — 胶囊操作按钮
- `ReviewRatingButtonStyle` — 复习评分格子按钮
- `.paperCardStyle()` / `.listItemStyle()` — ViewModifier

**字体**：词语/标题使用 Georgia 衬线体，正文使用系统无衬线。

### 视图文件

| 文件 | 对应 HTML 页面 |
|---|---|
| `Views/ImportView.swift` | 页面 1 · 导入 |
| `Views/ReviewView.swift` | 页面 2 · 今日复习 |
| `Views/SourceDetailView.swift` | 页面 3 · 回链详情 |
| `Views/VocabView.swift` | 页面 4 · 词表 |
| `Views/ProfileView.swift` | 页面 5 · 我的 |

设计参考原型：`docs/paper_vocab_iphone_mvp_v2.html`

## Status

iOS SwiftUI MVP 可构建（Xcode，`paper-loop/paper-loop.xcodeproj`）。后端 Python 服务（`backend/`）处于早期阶段，由 uv 管理依赖。
