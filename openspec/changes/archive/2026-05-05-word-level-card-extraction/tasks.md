## 1. 数据模型重构

- [x] 1.1 更新 `AnchorData.swift`：`.html` case 新增 `charOffset: Int?` 参数
- [x] 1.2 新建 `Models/Occurrence.swift`：SwiftData `@Model`，含 `termInContext`、`sourceSentence`、`anchorData: Data?`、`paper` 关联
- [x] 1.3 重构 `Models/Card.swift`：`term` 语义改为 lemma，移除 `sourceSentence` / `contextBefore` / `contextAfter` / `paper` 字段，新增 `occurrences: [Occurrence]` 关联（deleteRule cascade）
- [x] 1.4 在 `paper_loopApp.swift` 加清库逻辑：SwiftData container 初始化失败时 调用 `destroyAllData` 并重建

## 2. CardPipeline 重写

- [x] 2.1 更新 `LLMCardItem`：新增 `lemma`、`term_in_context`、`source_sentence`、`paragraph_idx` 字段；移除 `keep`/`value` 以外的旧字段适配
- [x] 2.2 重写 `systemPrompt`：输入为段落列表，要求 LLM 输出词/短语列表（`term_in_context` 原文照抄，不生成 sentence 类型）
- [x] 2.3 重写 `buildCandidatesJSON`：输出 `[{ idx: Int, text: String }]`，idx  为 batch-local 0-based
- [x] 2.4 重写 `processBatch`：接收 `batchOffset: Int` 参数，传入 `parseResponse` 用于全局 idx 换算
- [x] 2.5 重写 `parseResponse`：用 `paragraphs[batchOffset + item.paragraph_idx]` 取段落；`range(of: termInContext, options: .caseInsensitive)` 定位 charOffset ；失配则丢弃；返回含 `lemma`、`termInContext`、`charOffset` 的新版 `CardData`
- [x] 2.6 更新 `CardData` struct：新增 `lemma`、`termInContext`、`charOffset: Int?` 字段

## 3. ImportService 去重逻辑

- [x] 3.1 更新 `ImportService.startImport`：保存卡片时按 `lemma`（忽略大小写）查询已有 Card；存在则 append Occurrence，不存在则新建 Card + Occurrence
- [x] 3.2 构建 `Occurrence` 对象：用 `cardData.charOffset` 和段落 anchor 组合成 `AnchorData.html(elementId:, htmlURL:, charOffset:)` 或 `.pdf(page:, bbox:)`

## 4. 视图更新

- [x] 4.1 更新 `ReviewView.swift`：原句展示改为 `card.occurrences.last?.sourceSentence`；来源论文改为 `card.occurrences.last?.paper`
- [x] 4.2 重写 `SourceDetailView.swift`：展示 `card.occurrences` 列表，每条显示 论文标题、章节/页码、原句，并附"查看上下文"按钮跳转对应 anchor
- [x] 4.3 更新 `SourceDetailView` 的 `anchorLocationView`：从 `card.occurrences.last?.anchorData` 取值展示

## 5. 验证

- [ ] 5.1 导入一篇 arXiv 论文，确认生成的卡片 `term` 为单词/短语原型而非句子
- [ ] 5.2 导入同一论文两次，确认 lemma 相同的词不会重复创建 Card，只追加 Occurrence
- [ ] 5.3 导入两篇含相同词汇的论文，确认同一 Card 的 occurrences 包含两篇来源
- [ ] 5.4 点击"回到原文"，确认 SourceDetailView 展示所有 occurrences
- [ ] 5.5 点击某条 occurrence 的"查看上下文"，确认 WKWebView/PDFView 正确跳转
