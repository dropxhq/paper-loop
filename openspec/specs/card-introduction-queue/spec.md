## ADDED Requirements

### Requirement: 卡片 pending/active 状态
每张卡片 SHALL 拥有 `introducedAt: Date?` 字段标记其引入状态：`nil` 为 pending（待引入），有值为 active（已进入复习流程）。

#### Scenario: 新卡创建时为 pending
- **WHEN** 系统从论文中提取词汇生成卡片
- **THEN** `introducedAt = nil`，卡片不出现在复习队列中

#### Scenario: 引入后变为 active
- **WHEN** 系统将某张卡片加入当日复习队列
- **THEN** `introducedAt` 设为当前时间，`nextReviewAt` 设为当前时间

### Requirement: 每日新卡按优先级引入
系统 SHALL 在用户进入复习页时，从 pending 池中按优先级取出新卡并引入，直到当日新卡数量达到上限。

#### Scenario: 今日新卡槽位未满
- **WHEN** 用户进入复习页，且当日已引入新卡数 < 每日上限
- **THEN** 系统从 pending 池取出 top-N 卡片（N = 上限 - 当日已引入数），按优先级公式 `valueScore × log₂(occurrenceCount + 1)` 排序，设置 `introducedAt = now`，`nextReviewAt = now`

#### Scenario: 今日新卡槽位已满
- **WHEN** 用户进入复习页，且当日已引入新卡数 ≥ 每日上限
- **THEN** 不再引入新卡，pending 池不变

#### Scenario: pending 池为空
- **WHEN** 所有卡片均已被引入（`introducedAt != nil`）
- **THEN** 不执行引入操作，不报错

### Requirement: 每日新卡上限可配置
用户 SHALL 能在设置页配置每日新卡引入上限，默认值为 10。

#### Scenario: 默认上限
- **WHEN** 用户首次使用，未修改设置
- **THEN** 每日新卡上限为 10

#### Scenario: 用户修改上限
- **WHEN** 用户在 ProfileView 中调整每日新卡数量
- **THEN** 该设置持久化，下次进入复习页时生效

### Requirement: 数据迁移（一次性）
系统 SHALL 在升级后首次启动时，将历史卡片迁移至新状态模型。

#### Scenario: 从未复习的卡片迁移为 pending
- **WHEN** App 首次以新版本启动，存在 `repetitions == 0 && interval == 0` 的卡片
- **THEN** 这些卡片保持 `introducedAt = nil`，进入 pending 状态

#### Scenario: 已有复习记录的卡片迁移为 active
- **WHEN** App 首次以新版本启动，存在 `interval > 0` 或 `repetitions > 0` 的卡片
- **THEN** 这些卡片设置 `introducedAt = Date()`，视为已 active，复习记录保留

#### Scenario: 迁移不重复执行
- **WHEN** 迁移已执行过
- **THEN** 后续启动不再重复执行迁移逻辑
