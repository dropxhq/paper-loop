## MODIFIED Requirements

### Requirement: 今日复习卡片队列
系统 SHALL 按 SM-2 算法调度到期卡片，每次复习会话展示当前到期的已引入卡片队列。

#### Scenario: 有到期卡片
- **WHEN** 用户进入复习页
- **THEN** 展示所有 `introducedAt != nil && nextReviewAt ≤ now` 的卡片，按到期时间排序

#### Scenario: 今日无到期卡片
- **WHEN** 所有已引入卡片均未到期
- **THEN** 显示空状态：下次复习时间和已学卡片统计

#### Scenario: pending 卡片不出现在队列
- **WHEN** 存在 `introducedAt == nil` 的卡片
- **THEN** 这些卡片不出现在复习队列，不计入到期数量

### Requirement: 卡片翻转与答案展示
系统 SHALL 先展示正面（词/术语/句），用户主动触发后展示答案（释义、原句、上下文）。

#### Scenario: 词卡展示
- **WHEN** 展示词卡正面
- **THEN** 显示英文词/术语，提供"播放发音"和"显示答案"操作

#### Scenario: 句卡展示
- **WHEN** 展示句卡正面
- **THEN** 显示英文原句，提供"播放整句"和"显示答案"操作

#### Scenario: 展示答案
- **WHEN** 用户点击"显示答案"
- **THEN** 展示中文释义提示、来源论文名、"回到原文"入口

### Requirement: 四档记忆反馈与 SM-2 调度
用户 SHALL 能对卡片进行四档评级，系统据此更新下次复习时间。

#### Scenario: 记忆反馈评级
- **WHEN** 用户选择反馈（不认识=1 / 模糊=2 / 认识=3 / 已掌握=4）
- **THEN** 系统按 SM-2 算法计算新的 `interval`、`easeFactor` 并更新 `nextReviewAt`

#### Scenario: 首次复习
- **WHEN** 卡片首次被复习，评级为"认识"
- **THEN** `interval` 设为 1 天，`nextReviewAt = now + 1d`

### Requirement: TTS 发音播放
系统 SHALL 使用系统 TTS（AVSpeechSynthesizer）播放单词发音和整句朗读。

#### Scenario: 单词发音
- **WHEN** 用户点击"播放发音"
- **THEN** 系统以英式或美式英语朗读该单词/术语

#### Scenario: 整句朗读
- **WHEN** 用户点击"播放整句"
- **THEN** 系统朗读 `sourceSentence` 完整原句
