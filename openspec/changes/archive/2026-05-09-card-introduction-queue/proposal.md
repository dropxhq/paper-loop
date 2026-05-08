## Why

当前所有卡片在创建时 `nextReviewAt = now`，导致大量卡片立即堆积到期，用户每天只能复习其中一小部分，大批词汇始终排不上队，无法被有效学习。需要引入"新卡引入队列"机制，让词汇按价值优先级有序进入复习流程。

## What Changes

- 新增 `Card.introducedAt: Date?` 字段：`nil` 表示"待引入（pending）"，有值表示已进入复习流程
- 卡片创建时默认 `introducedAt = nil`，不再立即到期
- 每日复习开始时，系统按优先级公式从 pending 池中取出 N 张新卡引入（`introducedAt = now`，`nextReviewAt = now`）
- 优先级公式：`priority = valueScore × log₂(occurrenceCount + 1)`，兼顾词汇学习价值与跨论文出现频次
- **BREAKING**：数据迁移——现有 `repetitions == 0 && interval == 0` 的卡片重置为 pending 状态（`introducedAt = nil`，`nextReviewAt` 推入未来），已有复习记录的卡片保持不变
- 每日新卡上限（默认 10）通过 `AppStorage` 存储，可在 ProfileView 设置

## Capabilities

### New Capabilities

- `card-introduction-queue`: 卡片分为 pending / active 两种状态，每日按优先级公式从 pending 池有序引入新卡，控制每日新卡数量上限

### Modified Capabilities

- `review-loop`: 复习队列过滤逻辑需排除 pending 卡片（`introducedAt == nil`）

## Impact

- `Models/Card.swift` — 新增 `introducedAt` 字段
- `Views/ReviewView.swift` — `dueCards` 过滤加入 `introducedAt != nil` 条件；启动时触发新卡引入
- `Services/ReviewScheduler.swift` 或新建 `Services/CardIntroductionService.swift` — 实现引入逻辑
- `Views/ProfileView.swift` — 新增每日新卡上限设置项
- 数据迁移逻辑（App 启动时一次性执行）
