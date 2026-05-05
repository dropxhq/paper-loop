## Why

当前 CardPipeline 将整个段落作为候选项传给 LLM，导致生成的卡片是句子片段而非词/短语级别，且所有卡片彼此独立，同一单词在不同段落或不同论文中重复出现时无法关联。需要重新设计提取逻辑，使卡片真正以单词/短语为粒度，并支持跨段落、跨论文的 occurrence 聚合。

## What Changes

- **BREAKING** 重构 `Card` 数据模型：`term` 改为存储词原型（lemma），移除 `sourceSentence` / `contextBefore` / `contextAfter` / `paper` 字段，改由新增的 `Occurrence` 关联模型承载
- **BREAKING** 新增 `Occurrence` SwiftData Model，存储单次出现的词形（`termInContext`）、原句、anchor（含字符偏移）和来源论文
- `AnchorData.html` 枚举 case 新增 `charOffset: Int?` 字段，用于词级定位
- 重写 `CardPipeline` 的 LLM prompt：输入从"每段一个候选"改为"段落列表"，输出为词列表（每段可产出多个词），包含 `lemma`、`term_in_context`、`source_sentence`、`paragraph_idx` 字段
- 重写 `CardPipeline.parseResponse`：用 `range(of: termInContext)` 定位字符偏移，失配则丢弃；batch-local paragraph_idx 后处理为全局索引
- 导入时按 `lemma` 去重：已存在同 lemma 的 Card 则 append Occurrence，否则新建 Card
- 更新 `SourceDetailView`：展示所有 occurrences 列表，复习卡展示 `occurrences.last` 的原句
- 清库（不做 SwiftData migration，直接 deleteAllData）

## Capabilities

### New Capabilities

- `occurrence-model`: 新增 `Occurrence` Model，承载单次出现的词形、原句、anchor 和来源论文

### Modified Capabilities

- `card-generation`: LLM 输入/输出契约改为段落→词列表（N:M），新增 lemma / term_in_context / paragraph_idx 字段；卡片粒度从句子级改为词/短语级
- `source-backlink`: AnchorData 新增 charOffset；SourceDetailView 展示 occurrences 列表而非单条来源

## Impact

- `Models/Card.swift` — 字段重构（breaking）
- `Models/AnchorData.swift` — 新增 charOffset
- `Models/Occurrence.swift` — 新建文件
- `Services/CardPipeline.swift` — LLM prompt 和解析逻辑完全重写
- `Services/ImportService.swift` — 保存逻辑加 lemma 去重
- `Views/SourceDetailView.swift` — 展示 occurrences 列表
- `Views/ReviewView.swift` — 取 occurrences.last 的原句展示
- SwiftData schema 变化，需在 App 启动时清库
