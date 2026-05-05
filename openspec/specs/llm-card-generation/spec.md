## ADDED Requirements

### Requirement: 分批调用 LLM 生成词卡
系统 SHALL 将段落列表分成每批 ≤30 段，并发调用 LLM（OpenAI-compatible API），单步 prompt 完成候选词提取、过滤和中文释义生成。

#### Scenario: 正常批量生成
- **WHEN** 段落数组非空，API Key 有效
- **THEN** 系统分批（≤30 段/批）并发调用 LLM，合并所有批次结果，返回 Card 对象数组

#### Scenario: 单批失败
- **WHEN** 某一批次 LLM 调用返回错误或超时
- **THEN** 该批次返回空结果，其他批次继续，不中断整个导入流程；UI 可提示"部分内容生成失败"

### Requirement: LLM 返回结构化 JSON 词卡
系统 SHALL 要求 LLM 严格返回 JSON 数组，每个元素包含 `term`、`type`（word/phrase/sentence）、`zh_hint`、`value`（1-5）、`keep`（bool）字段；`keep=false` 或 `value≤2` 的条目 SHALL 被过滤。

#### Scenario: JSON 解析成功
- **WHEN** LLM 返回合法 JSON 数组
- **THEN** 系统过滤 `keep=false` 和 `value≤2` 的条目，其余转换为 Card 对象（含 `sourceSentence` 和 `anchor`）

#### Scenario: JSON 解析失败
- **WHEN** LLM 返回非 JSON 内容或格式错误
- **THEN** 系统丢弃该批次结果，记录日志，不崩溃

### Requirement: API Key 缺失时阻止导入
系统 SHALL 在导入开始前检测 LLM API Key 是否已配置；若未配置，SHALL 阻止导入并引导用户前往设置页。

#### Scenario: API Key 未配置
- **WHEN** 用户点击"导入论文"但 Keychain 中无 LLM API Key
- **THEN** 系统不发起任何网络请求，ImportState 设为 `failed`，提示"请先在"我的"页设置 API Key"
