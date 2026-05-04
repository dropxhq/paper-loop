## Why

当前 PaperLoop 存在三个影响使用体验的质量问题：TTS 发音使用系统默认 compact voice 效果诡异；后端词卡抽取混入了大量公式残片和数字，降低复习价值；同一篇论文可被重复导入而无任何提示。同时缺少对已导入论文的管理能力（查看、删除、跳转词卡）。趁 MVP 尚在打磨期，集中解决这几个点，建立稳定的质量基线。

## What Changes

- **TTS 引擎升级**：优先使用 iOS enhanced/premium Apple Neural Voice，降级链路为 enhanced → default；首次使用时若最佳声音未下载，引导用户前往系统设置下载。
- **词卡过滤策略**：后端抽取时过滤掉含非 ASCII 字符、纯数字、LaTeX 残片（`\`、`{`、`}`、`_`、`^`）的候选项；保留多词短语但须通过严格过滤；使用 spaCy lemma 归一化 term，支持跨论文词卡聚合。去掉 RAKE 管道，保留 spaCy NER + AWL 单词匹配。
- **重复导入去重**：客户端在触发导入前检查本地是否存在同 `arxivId` 的 Paper；若存在，弹出操作表提示用户：跳转已有词卡 / 合并（追加新词卡）/ 替换（删除旧词卡重新生成）。
- **Paper 管理**：`ProfileView` 的论文列表支持滑动删除（级联删除所有词卡）；点击论文进入新增的 `PaperDetailView`，展示该论文信息与全部词卡列表，并提供"重新导入"入口。`PaperDetailView` 同时作为去重流程"跳转已有词卡"的落点页面。

## Capabilities

### New Capabilities

- `tts-voice-selection`: 离线 TTS 声音质量优选逻辑，含声音降级链与用户引导
- `card-extraction-filter`: 后端词卡候选过滤规则（公式/数字/LaTeX 过滤 + lemma 归一化）
- `paper-dedup`: 重复导入检测与操作表（跳转 / 合并 / 替换）
- `paper-management`: Paper 列表滑动删除 + PaperDetailView 详情与管理页

### Modified Capabilities

- `card-generation`: 抽取管道从三路（NER + AWL + RAKE）缩减为两路（NER + AWL），增加过滤规则；term 字段改存 lemma

## Impact

- **iOS（Swift）**：`ReviewView.swift`（TTS 逻辑）、`ImportView.swift`（去重检测）、`ProfileView.swift`（删除 + 导航）、新增 `PaperDetailView.swift`
- **后端（Python）**：`backend/src/services/extractor.py`（过滤规则 + 去掉 RAKE + lemma 归一化）
- **依赖**：移除 `rake_nltk`（或保留但不调用），无新增依赖
- **数据**：Card 模型的 `term` 字段语义变更（存 lemma），已有词卡不受影响（无迁移需求）
