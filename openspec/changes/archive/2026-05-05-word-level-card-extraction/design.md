## Context

当前 `CardPipeline` 将每个 `Paragraph`（HTML `<p>` 或 PDF 文本块）整体作为一个候选项传给 LLM，每段产出最多一张卡片。这导致：1）卡片是句子片段而非词/短语；2）`term` 字段存的是截断的 120 字符句子；3）同一单词多次出现无法聚合，`occurrenceCount` 字段形同虚设。

`Card` 当前是 SwiftData `@Model`，直接持有 `sourceSentence`、`paper` 等字段。重构涉及 SwiftData schema 变化，MVP 阶段选择清库而非 migration。

## Goals / Non-Goals

**Goals:**
- LLM 输入变为段落列表，输出为词/短语列表（一段可产出多个卡片）
- `Card.term` 存储词原型（lemma），跨段落、跨论文相同 lemma 共享同一 Card
- 每次出现存为独立 `Occurrence`，含词形（`termInContext`）、原句、anchor、来源论文
- `AnchorData.html` 新增 `charOffset`，通过 `range(of: termInContext)` 在段落文本中定位
- `SourceDetailView` 展示所有 occurrences，复习卡展示 `occurrences.last`
- 清库完成 schema 迁移

**Non-Goals:**
- 词级 HTML 高亮（WKWebView JS 注入）——charOffset 存下来但本期不实现高亮
- 规则预处理（NLP 分词）——全部交给 LLM
- PDF 字符偏移定位——PDF 继续用 PDFKit `findString`，不存 offset

## Decisions

### D1：LLM 输入/输出契约重设计

**选择**：输入为 `[{ idx: Int, text: String }]`（段落列表），输出为词列表，每词含 `lemma`、`term_in_context`、`source_sentence`、`paragraph_idx`、`type`、`zh_hint`、`value`、`keep`。

**理由**：让 LLM 同时完成"从段落抽词"和"评分筛选"两件事，避免引入规则分词依赖。`term_in_context` 要求 LLM 原文照抄，保证 `range(of:)` 能匹配。

**备选**：先用规则（NLP 分词）抽候选词再交 LLM 评分——复杂度更高，且 iOS 上无合适的 NLP 库处理学术英文。

### D2：batch-local idx → 全局 idx 后处理

**选择**：`buildCandidatesJSON` 给段落编 batch-local idx（0..<batchSize），`parseResponse` 收到结果后加上 `batchOffset` 换算为全局 idx，再通过 `paragraphs[globalIdx]` 取 anchor。

**理由**：LLM 看到的 idx 从 0 开始，简单直观，不易出错。后处理一行加法即可。

### D3：失配丢弃策略

**选择**：`range(of: termInContext, options: .caseInsensitive)` 找不到时丢弃该词，不降级保留。

**理由**：LLM 若改写了词形说明返回质量有问题，保留一张 anchor 错误的卡片比丢掉更糟糕。

### D4：按 lemma 去重

**选择**：导入时查询 `Card` 中是否已有相同 `lemma`（忽略大小写）的记录，存在则 append `Occurrence`，否则新建 `Card`。

**理由**：用户学习的是词原型，跨论文看到同一个词的多处原文有助于加深理解。SwiftData 查询 lemma 成本低。

### D5：SwiftData 清库

**选择**：App 启动时检测到 schema 不兼容则 `destroyAllData`，不写 migration。

**理由**：MVP 阶段无真实用户数据需要保留，migration 开发成本不值得。

## Risks / Trade-offs

- **LLM 词形改写** → `term_in_context` 匹配失败、卡片丢失。Prompt 强调"原文照抄"，失配时丢弃（D3）。长期可考虑 fuzzy match。
- **LLM 输出量激增** → 一段落产出多个词，token 消耗增加。已有 batchSize=30 控制，可视实测调整。
- **并发 LLM 请求无限速** → 大论文可能同时发出 10+ 请求。当前 MVP 接受此风险，后续可加信号量限制并发数。
- **清库影响开发调试** → 每次 schema 变化都清库，开发期间需要重新导入测试数据。可接受。

## Migration Plan

1. 更新 `AnchorData`、新建 `Occurrence`、重构 `Card`
2. App 启动入口（`paper_loopApp.swift`）加清库逻辑：捕获 SwiftData init 错误或版本不匹配时调用 `destroyAllData`
3. 重写 `CardPipeline` prompt 和解析逻辑
4. 更新 `ImportService` 去重保存逻辑
5. 更新 `SourceDetailView` 和 `ReviewView`
6. 在模拟器上清除 App 数据后完整走一遍导入→复习流程验证

## Open Questions

- Prompt 中对 `term_in_context` "原文照抄"的强调是否足够？是否需要在 system prompt 中加示例（few-shot）来提高准确率？
- `charOffset` 本期只存不用，未来高亮时是字节偏移还是 Swift `String.Index`？（建议存 UTF-16 offset 以与 NSString / JS 兼容）
