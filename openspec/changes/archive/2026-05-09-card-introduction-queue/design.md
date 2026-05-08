## Context

当前所有卡片在创建时 `nextReviewAt = Date()`，导致全部卡片立即进入到期队列。用户每天只能复习约 25 张，而积压的数百张卡片中，大部分词汇永远轮不到。需要引入"pending / active"两阶段状态，让词汇按优先级有序引入复习流程。

现有模型：
- `Card.repetitions`：SM-2 重置时会归零，无法区分"从未学过"和"学了但忘了"
- `Card.interval`：首次成功复习后 interval=1，失败后重置为1；`interval == 0` 只在卡片从未被成功复习时出现

## Goals / Non-Goals

**Goals:**
- 卡片分为 pending（待引入）和 active（复习中）两种状态
- 每日从 pending 池按优先级引入固定数量新卡
- 优先级公式：`valueScore × log₂(occurrenceCount + 1)`
- 历史数据无损迁移（已有复习记录保留）
- 每日新卡上限用户可配置

**Non-Goals:**
- 不修改 SM-2 调度算法本身
- 不对已 active 卡片重新排序
- 不提供手动"立即引入"某张卡片的 UI（可后续添加）

## Decisions

### 决策一：用 `introducedAt: Date?` 区分 pending / active

**选择**：新增 `Card.introducedAt: Date?`，`nil` = pending，有值 = active。

**备选方案**：
- 用 `repetitions == 0 && interval == 0` 推断 pending → 被否定，因为 SM-2 失败会重置 `repetitions=0`，无法区分
- 新增 `Bool` 字段 `isPending` → 语义等价但可读性更差，且丢失引入时间信息

**理由**：`Date?` 既携带状态又携带时间戳，SwiftData 支持可选 Date，迁移简单。

---

### 决策二：优先级公式使用对数加权

**选择**：`priority = valueScore × log₂(occurrenceCount + 1)`

**理由**：
- `valueScore`（3-5）捕捉词汇本身的学习价值（LLM 判断）
- `occurrenceCount` 捕捉跨论文出现频次，频次越高说明越是领域核心词
- 对数压缩：出现 1 次 vs 2 次差距大，10 次 vs 11 次差距小，符合收益递减直觉
- 不需要持久化：每次引入时内存计算，pending 池规模上千时仍可接受

---

### 决策三：引入逻辑放在 ReviewView 启动时

**选择**：进入 ReviewView 时调用 `CardIntroductionService.introduceIfNeeded()`，检查今日已引入数量，不足则补充。

**理由**：引入行为与"开始复习"强关联，用户进入复习页就是当日的触发点。不需要后台定时器。

**边界**：同一天多次进入 ReviewView 不会重复引入（通过检查今日 `introducedAt` 数量判断）。

---

### 决策四：迁移策略选 B（pending 重置）

**选择**：`repetitions == 0 && interval == 0` 的卡片视为真正的新卡，重置为 pending（`introducedAt = nil`）。其余保留。

**判断依据**：
- `interval == 0`：卡片从未被成功完成一次复习（SM-2 失败会重置 repetitions 但 interval 已变为 1）
- 已有复习记录（`interval > 0` 或 `repetitions > 0`）的卡片不受影响

## Risks / Trade-offs

- **迁移后用户感知到"队列清空"** → 已有复习记录的词不受影响；全新卡片会逐步出现，体验更可控，风险可接受
- **log₂ 精度差异小** → valueScore 只有 3-5 三档，公式细分有限；未来可加入更多信号
- **SwiftData Schema 变更需要迁移版本** → 需要添加 `VersionedSchema` 或使用轻量级迁移，不能直接加字段

## Migration Plan

1. 增加 SwiftData schema 版本，新增 `introducedAt: Date?` 字段（默认 `nil`）
2. App 首次启动新版本时，执行一次性迁移：
   - 扫描所有 `repetitions == 0 && interval == 0` 的卡片 → 保持 `introducedAt = nil`
   - 其余卡片 → 设置 `introducedAt = createdDate`（或当前时间，作为兼容值）
3. 迁移完成后写入 `UserDefaults` 标记，避免重复执行

**回滚**：SwiftData 不支持自动回滚；但 `introducedAt` 字段不影响现有数据，最坏情况删除字段重新迁移。
