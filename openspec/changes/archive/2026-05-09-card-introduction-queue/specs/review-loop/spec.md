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
