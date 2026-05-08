## 1. 数据模型

- [x] 1.1 在 `Card.swift` 中新增 `introducedAt: Date?` 字段（默认 `nil`）
- [x] 1.2 添加 SwiftData schema 版本迁移，确保现有数据库可升级

## 2. 数据迁移

- [x] 2.1 在 `paper_loopApp.swift` 中实现一次性迁移函数：`repetitions == 0 && interval == 0` 的卡片保持 `introducedAt = nil`，其余设为 `Date()`
- [x] 2.2 使用 `UserDefaults` 标记迁移已完成，防止重复执行

## 3. 新卡引入服务

- [x] 3.1 新建 `Services/CardIntroductionService.swift`
- [x] 3.2 实现 `introduceIfNeeded(context:dailyLimit:)` 函数：查询今日已引入数量，计算剩余槽位
- [x] 3.3 实现优先级排序：从 pending 池取卡片，按 `valueScore × log₂(occurrenceCount + 1)` 降序排列
- [x] 3.4 对 top-N 卡片设置 `introducedAt = now`，`nextReviewAt = now`

## 4. 复习队列过滤

- [x] 4.1 修改 `ReviewView.dueCards` 过滤条件：添加 `$0.introducedAt != nil` 判断
- [x] 4.2 在 `ReviewView.onAppear`（或 `task`）中调用 `CardIntroductionService.introduceIfNeeded()`

## 5. 设置项

- [x] 5.1 在 `ProfileView.swift` 中新增"每日新卡数量"设置项，使用 `@AppStorage("dailyNewCardLimit")` 存储，默认值 10
- [x] 5.2 `CardIntroductionService` 读取该 `AppStorage` 值作为上限
