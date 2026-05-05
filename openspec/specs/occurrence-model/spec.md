## Requirements

### Requirement: Occurrence 数据模型
系统 SHALL 提供 `Occurrence` SwiftData Model，存储单词在某篇论文某个位置的一次出现记录。

#### Scenario: Occurrence 字段完整
- **WHEN** 一个词被成功提取并定位
- **THEN** 创建 Occurrence，包含：`termInContext`（原文词形）、`sourceSentence`（含该词的句子）、`anchorData`（HTML elementId + charOffset 或 PDF page）、`paper`（来源论文）

#### Scenario: HTML anchor 含字符偏移
- **WHEN** Occurrence 对应 HTML 格式论文
- **THEN** `anchorData` 为 `.html(elementId:, htmlURL:, charOffset:)`，其中 `charOffset` 为 `termInContext` 在段落文本中的 UTF-16 起始偏移

#### Scenario: PDF anchor 无字符偏移
- **WHEN** Occurrence 对应 PDF 格式论文
- **THEN** `anchorData` 为 `.pdf(page:, bbox:)`，不含字符偏移

### Requirement: Card 通过 Occurrence 聚合多次出现
Card SHALL 通过 `occurrences` 关联持有所有出现记录，复习时展示最新 Occurrence 的原句。

#### Scenario: 复习卡展示最新原句
- **WHEN** 用户复习某张 Card
- **THEN** 展示 `occurrences.last` 的 `sourceSentence` 和 `paper`

#### Scenario: Card 无 Occurrence 时降级
- **WHEN** Card 的 `occurrences` 为空（数据异常）
- **THEN** 原句和来源论文显示为空，不崩溃
