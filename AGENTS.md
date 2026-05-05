# PaperLoop — Agent Instructions

学术论文 PDF → 词汇/术语/句型闪卡（发音、原文回链、间隔复习）。iPhone-first MVP。

## Architecture

| Layer | Path | Notes |
|---|---|---|
| iOS App (SwiftUI) | `paper-loop/paper-loop/` | Primary platform, SwiftData persistence |
| Python Backend | `backend/` | Early stage, uv-managed |
| Design Reference | `docs/paper_vocab_iphone_mvp_v2.html` | Source of truth for visual design |
| Specs | `openspec/specs/` | Per-feature spec files |

## Build & Run

**iOS**: open `paper-loop/paper-loop.xcodeproj` in Xcode, build/run normally.  
**Python scripts**: `uv run --env-file .env <script>`  
**Backend dev server**: `just backend`  
**Install backend deps**: `just backend-install`

## iOS Conventions

### Design System
All tokens are in [`paper-loop/paper-loop/Theme.swift`](paper-loop/paper-loop/Theme.swift). **Always use `Theme.*` — never hardcode colors or radii.**

Key tokens: `Theme.bg` (warm cream background), `Theme.surface` (card bg), `Theme.primary` (#0c6865 teal), `Theme.textPrimary`, `Theme.textMuted`.  
Corner radii: cards `r24`, list rows `r18`, buttons/inputs `r16`.

Reusable components from `Theme.swift`: `EyebrowBadge`, `SectionHeader`, `MiniStatBox`, `PrimaryButtonStyle`, `ChipButtonStyle(filled:)`, `ReviewRatingButtonStyle`, `.paperCardStyle()`, `.listItemStyle()`.

Typography: term/headings use `Font.custom("Georgia", size: N)`, body uses system sans-serif.

### Data Models (SwiftData)
`Paper` → `Occurrence` → `Card` (many-to-many via `Occurrence`). `ReviewLog` tracks spaced-repetition history. Schema lives in `Models/`.

### View Files
| File | Screen |
|---|---|
| `Views/ImportView.swift` | Page 1 · Import |
| `Views/ReviewView.swift` | Page 2 · Today's Review |
| `Views/SourceDetailView.swift` | Page 3 · Source backlink |
| `Views/VocabView.swift` | Page 4 · Vocabulary list |
| `Views/ProfileView.swift` | Page 5 · Profile / Settings |

### Services
- `ImportService` — orchestrates arXiv fetch → LLM card generation
- `CardPipeline` — batched LLM card extraction (batch size 30); LLM prompt text is **in Chinese**
- `LLMService` — OpenAI-compatible API; key stored in Keychain via `KeychainHelper`
- `ArXivFetchService` — HTML-preferred, PDF fallback
- `DoubaoTTSService` / DashScope TTS — for pronunciation

**All LLM/AI prompt text in this project is maintained in Chinese.**

## OpenSpec Workflow
Feature specs live in `openspec/specs/<feature>/spec.md`. Active changes in `openspec/changes/`. Archived changes in `openspec/changes/archive/`. See skills: `openspec-propose`, `openspec-apply-change`, `openspec-archive-change`.
