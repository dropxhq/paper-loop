## Context

PaperLoop 是 iPhone-first 的学术论文词卡应用，当前 MVP 可构建运行。发现四个影响使用质量的问题：

1. **TTS**：`AVSpeechSynthesizer` 使用 `AVSpeechSynthesisVoice(language: "en-US")` 默认选 compact voice，发音机械诡异。iOS 16+ 提供 enhanced/premium Neural Voice（Siri 同款），质量大幅更好，且完全离线。
2. **词卡噪声**：PyMuPDF 解析 PDF 时，数学公式、LaTeX 命令、数字序列混入段落文本，被 RAKE 和 NER 管道抓成候选词，生成无意义词卡。
3. **重复导入**：`ImportView` 无任何去重逻辑，同一篇论文可被反复导入，SwiftData 产生重复 Paper + Card 记录，消耗 LLM 费用。
4. **Paper 管理**：`ProfileView` 已有论文列表但仅展示，无删除、无详情页，用户无法管理积累的论文。

## Goals / Non-Goals

**Goals:**
- 使用 Apple Neural Voice（enhanced/premium）改善发音质量，保持完全离线
- 后端过滤公式/数字/LaTeX 残片，保留有价值的单词和短语，term 存 lemma 支持跨论文聚合
- 客户端 arxivId 去重，提供跳转 / 合并 / 替换三个操作
- ProfileView 论文列表支持删除；新增 PaperDetailView 展示词卡 + 重新导入入口

**Non-Goals:**
- 云端 TTS（OpenAI、ElevenLabs 等）—— 留待后续
- 后端持久化缓存去重 —— 客户端去重足够 MVP
- 词卡编辑（修改 term / zhHint）—— 独立需求
- 历史复习数据迁移 —— 本次不涉及数据迁移

## Decisions

### D1：TTS 选声音策略

**决策**：运行时枚举所有 `en-*` voices，按 `.premium > .enhanced > .default` 优先级选最好的，缓存到 `ReviewView` 初始化时。

**备选方案**：
- 硬编码 `com.apple.ttsbundle.siri_*` identifier —— 脆弱，不同设备标识符不同
- 云端 TTS —— 需要网络，增加后端复杂度，MVP 阶段不必要

**引导逻辑**：若最优只到 `.default`，在词卡页底部展示一次性 banner，提示用户去 设置 → 辅助功能 → 语音内容 下载 Enhanced 声音，dismissed 后不再显示（`@AppStorage`）。

---

### D2：词卡过滤规则

**决策**：在 `extractor.py` 的 `extract_candidates` 出口处统一过滤，规则如下（任一命中即丢弃）：

```
1. 含非 ASCII 字符（unicode 数学符号、希腊字母碎片）
2. 全数字 / 纯百分比 / 以数字开头的 token
3. 含 LaTeX 命令字符：\ { } _ ^ $
4. 长度 < 4 字符
5. 多词短语中任一词命中上述规则（短语级别联合过滤）
6. 多词短语超过 5 个词（过长通常是噪声句子）
```

term 字段改为 spaCy `token.lemma_`（单词）或短语 head token 的 lemma（短语）。

**备选方案**：
- 正则白名单（只允许 `[a-zA-Z\-]`）—— 太激进，会过滤连字符术语如 `fine-tuning`
- 去掉整个 NER 管道只保留 AWL —— 损失命名实体（模型名、数据集名），价值大

**去掉 RAKE 的理由**：RAKE 设计目标是多词关键词，抗噪能力差，且与 NER 重复度高；去掉后可移除 `rake_nltk` 依赖，降低依赖树复杂度。

---

### D3：去重流程

**决策**：客户端 `startImport` 触发前先执行 SwiftData fetch，查 `arxivId == inputId`。

```
用户点击导入
    ↓
提取 arxivId（本地正则解析 URL）
    ↓
SwiftData fetch: Paper WHERE arxivId == x
    ↓
已存在？ ──是──→ ActionSheet
                  ├── 查看已有词卡  → navigate to PaperDetailView
                  ├── 合并        → 导入并 append 新卡（去 term 重复）
                  └── 替换        → 删除旧 Paper + Cards，重新导入
         │
        否
         ↓
    正常导入流程
```

合并时 term 去重：以 `term.lowercased()` 为 key，已有 Card 不再插入。

**备选方案**：
- 服务端去重（缓存 arxivId → job result）—— 需要持久化存储，MVP 过重
- 静默跳过（不提示）—— 体验不透明，用户无法感知发生了什么

---

### D4：Paper 管理页设计

**决策**：
- `ProfileView` 论文 row 用 `.swipeActions` 加删除按钮（`deleteRule: .cascade` 已配置，直接 `modelContext.delete`）
- 新增 `PaperDetailView`，接收 `Paper` 参数，展示：论文元信息、该论文的 Card 列表（复用 `VocabRowView`）、底部"重新导入"按钮
- 去重流程的"查看已有词卡"跳转到 `PaperDetailView`

`PaperDetailView` 的 Card 查询：`@Query` 无法直接按关系过滤，使用 `paper.cards` 关系属性直接取（已有 `@Relationship`）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Enhanced voice 未下载时 banner 被忽视，用户仍听到 compact voice | Banner 文案清晰，提供深度链接 `UIApplication.openSettingsURLString`（Settings 入口），一次引导即可 |
| 过滤规则过激导致有价值短语丢失（如 `F1-score`、`top-k`） | 连字符术语不触发过滤（只过滤 LaTeX 特殊字符），数字连字符组合（`top-k`）保留；上线后可通过 VocabView 观察词卡质量调整阈值 |
| lemma 归一化导致 term 显示不自然（`running` → `run`）| 单词卡存 lemma，`sourceSentence` 保留原文语境；术语短语不做 lemma（保留原型如 `attention mechanism`） |
| 合并导入时新卡 term 去重不够精准（大小写、词形变化）| 以 `term.lowercased()` 为键，足够 MVP；后续可改为 lemma 比对 |
| PaperDetailView 大量词卡时性能 | 使用 `LazyVStack`，与 `VocabView` 一致 |

## Open Questions

- 用户引导下载 Enhanced voice 的 banner，是放在 `ReviewView` 还是 app 首次启动时？（倾向：首次播放时触发）
- 合并导入后是否重新计算所有 Card 的 `nextReviewAt`？（倾向：新卡用初始值，旧卡不变）
