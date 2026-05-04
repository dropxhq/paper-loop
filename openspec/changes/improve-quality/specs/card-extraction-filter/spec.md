## ADDED Requirements

### Requirement: 过滤公式、数字和 LaTeX 残片
后端 `extract_candidates` SHALL 在返回候选词前，过滤掉含以下特征的 term（任一命中即丢弃）：
- 含非 ASCII 字符（unicode 数学符号、希腊字母等）
- 全部为数字，或以数字开头
- 含 LaTeX 命令字符（`\`、`{`、`}`、`_`、`^`、`$`）
- 长度小于 4 字符
- 多词短语中任一词命中上述规则
- 多词短语超过 5 个词

#### Scenario: 公式碎片被过滤
- **WHEN** 抽取候选词时出现含 unicode 数学符号的 term（如 `αij`、`∑`）
- **THEN** 该 term 被丢弃，不生成词卡

#### Scenario: 数字序列被过滤
- **WHEN** 抽取候选词时出现以数字开头的 term（如 `0.85`、`3.14`、`ResNet50` 中的纯数字部分）
- **THEN** 该 term 被丢弃，不生成词卡

#### Scenario: 连字符术语被保留
- **WHEN** 抽取候选词时出现连字符术语（如 `fine-tuning`、`top-k`、`F1-score`）
- **THEN** 该 term 通过过滤，正常生成词卡

#### Scenario: 有效多词短语被保留
- **WHEN** 抽取候选词时出现 2-5 词的纯英文术语短语（如 `attention mechanism`）
- **THEN** 该 term 通过过滤，正常生成词卡

### Requirement: 使用 lemma 存储 term
系统 SHALL 将单词类型的 term 存为 spaCy `token.lemma_`（小写原型），短语类型的 term 保留原文（不做 lemma）。

#### Scenario: 单词 term 归一化
- **WHEN** 文本中出现 "running"、"runs"、"ran" 等词形变化
- **THEN** 生成的词卡 term 均存为 lemma（如 `run`），不产生重复词卡

#### Scenario: 短语 term 保留原文
- **WHEN** 抽取到 `attention mechanism`、`pre-trained model` 等多词短语
- **THEN** term 字段存储原始短语形式，不做 lemma 处理

### Requirement: 移除 RAKE 管道
系统 SHALL 仅使用 spaCy NER 和 AWL 单词匹配两条管道，不再使用 RAKE 提取多词关键词。

#### Scenario: RAKE 管道已移除
- **WHEN** 后端处理论文段落
- **THEN** 不调用 `rake_nltk` 的任何方法，候选词仅来自 NER 和 AWL
