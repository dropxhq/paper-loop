## ADDED Requirements

### Requirement: 规则候选词抽取
系统 SHALL 使用规则方法从段落文本中抽取候选词、术语短语，作为 LLM 筛选的输入。

#### Scenario: 多词术语识别
- **WHEN** 段落含有 "attention mechanism"、"self-supervised learning" 等术语短语
- **THEN** 候选列表包含完整短语，而非分割为单词

#### Scenario: 普通高频词过滤
- **WHEN** 段落含有 "the"、"this"、"model" 等低价值词
- **THEN** 候选列表不包含这些词

### Requirement: LLM 筛选与分类
系统 SHALL 将规则候选列表发送给 Claude Haiku，返回分类、价值评分和中文释义提示。

#### Scenario: 词卡生成
- **WHEN** 候选词为单独学术词汇（如 "contrastive"）
- **THEN** 返回 `type: "word"`，含 `zh_hint`（中文释义），`value` 1–5 分

#### Scenario: 术语卡生成
- **WHEN** 候选词为领域术语短语（如 "masked language modeling"）
- **THEN** 返回 `type: "phrase"`，含完整术语和 `zh_hint`

#### Scenario: 句卡生成
- **WHEN** 候选句为定义句、方法句或贡献句
- **THEN** 返回 `type: "sentence"`，含完整原句和句型标注

#### Scenario: 低价值候选过滤
- **WHEN** 候选词价值评分 ≤ 2
- **THEN** `keep: false`，不生成对应卡片

### Requirement: 卡片包含完整来源信息
每张生成的卡片 SHALL 包含 `source_sentence`、`context_before`、`context_after` 和对应 anchor。

#### Scenario: 卡片来源字段完整
- **WHEN** 卡片生成完成
- **THEN** 卡片包含 `sourceSentence`（原句）、`contextBefore`（前一句）、`contextAfter`（后一句）、`anchor`（HTML element ID 或 PDF page+bbox）

### Requirement: 自动去重归并
系统 SHALL 对同一 paper 内相同词条、词族和重复术语自动合并为单张卡片。

#### Scenario: 同词多次出现
- **WHEN** "transformer" 在论文中出现 15 次
- **THEN** 仅生成 1 张卡片，`occurrenceCount: 15`
