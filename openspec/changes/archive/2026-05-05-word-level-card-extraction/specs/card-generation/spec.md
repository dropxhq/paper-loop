## MODIFIED Requirements

### Requirement: LLM 筛选与分类
系统 SHALL 将段落列表发送给 LLM，每个段落可产出零到多个词/短语卡片数据。

#### Scenario: 词卡生成
- **WHEN** 段落含有学术单词（如 "contrastive"）
- **THEN** LLM 返回该词的条目，含 `lemma`（原型）、`term_in_context`（原文词形，原样照抄）、`source_sentence`（含该词的完整句子）、`type: "word"`、`zh_hint`、`value` 1–5 分

#### Scenario: 术语卡生成
- **WHEN** 段落含有领域术语短语（如 "masked language modeling"）
- **THEN** 返回 `type: "phrase"`，`lemma` 为短语原型，`term_in_context` 原文照抄

#### Scenario: 一段落产出多个词
- **WHEN** 段落含有 3 个有价值的学术词汇
- **THEN** LLM 输出包含 3 个独立条目，每个条目含各自的 `term_in_context` 和 `source_sentence`

#### Scenario: 低价值候选过滤
- **WHEN** 候选词价值评分 ≤ 2
- **THEN** `keep: false`，不生成对应卡片

#### Scenario: sentence 类型不再生成
- **WHEN** LLM 处理段落
- **THEN** 不生成 `type: "sentence"` 的卡片；仅生成 `word` 和 `phrase`

### Requirement: 卡片包含完整来源信息
每张生成的卡片 SHALL 包含 `source_sentence` 和对应 anchor（含字符偏移）。

#### Scenario: HTML 卡片 anchor 含偏移
- **WHEN** 卡片来源为 HTML 格式论文，且 `range(of: termInContext)` 匹配成功
- **THEN** anchor 为 `.html(elementId:, htmlURL:, charOffset:)`，charOffset 为词在段落文本的 UTF-16 起始偏移

#### Scenario: 词形定位失败时丢弃
- **WHEN** `range(of: termInContext, options: .caseInsensitive)` 在段落文本中找不到匹配
- **THEN** 该词条被丢弃，不生成卡片

### Requirement: 自动去重归并
系统 SHALL 对相同 lemma（忽略大小写）的词条归并为同一张 Card，每次新出现追加 Occurrence。

#### Scenario: 同 lemma 跨段落归并
- **WHEN** 同一论文两个段落都提取出 lemma="capability" 的词条
- **THEN** 只有一张 Card（lemma="capability"），含两个 Occurrence

#### Scenario: 同 lemma 跨论文归并
- **WHEN** 导入第二篇论文时提取出已存在的 lemma
- **THEN** 在同一张 Card 上追加新 Occurrence，Card 的 occurrences 增加

#### Scenario: 新 lemma 创建 Card
- **WHEN** 提取出的 lemma 在数据库中不存在
- **THEN** 创建新 Card，`term` = lemma，`occurrences` 含首个 Occurrence
