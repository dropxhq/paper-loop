## Why

当前词表在词卡量上来后检索成本明显升高，用户需要更快地按首字母定位词条；同时“查看上下文/回到原文”在 arXiv 页面慢加载与失败场景下缺少明确反馈，容易被感知为点击无响应。该变更用于提升高频查词路径效率，并修复原文回链在真实网络环境下的可用性问题。

## What Changes

- 在词表页新增右侧字母索引（A-Z + #），支持按压与滑动实时定位到对应首字母分组。
- 词表列表默认按字母升序展示，并对非字母开头词条归入 `#` 分组。
- 在打开 HTML/PDF 原文时增加统一加载页面（loading state），展示明确的“正在加载”反馈。
- 为原文阅读增加可见错误状态与重试操作，避免静默失败。
- 修正“查看上下文”回链链路中的页码/锚点定位一致性问题，确保定位到正确上下文。
- 当 HTML 回链不可用时提供可预期的降级路径（例如回退 PDF）。

## Capabilities

### New Capabilities
- `vocab-alphabet-index`: 词表提供按首字母快速导航的侧边索引交互与分组定位能力。

### Modified Capabilities
- `source-backlink`: 扩展原文打开流程的加载/失败反馈、HTML 不可用时的降级行为，并收敛锚点定位一致性要求。

## Impact

- 受影响视图：`VocabView`、`SourceDetailView`、`HTMLReaderView`、`PDFReaderView`、`ReviewView`（复习页“回到原文”入口共享回链能力）。
- 受影响服务与模型：`ImportService`、`ArXivFetchService`、`AnchorData`/anchor 使用链路（主要是行为与一致性约束）。
- 无新增后端依赖；主要为 iOS 端 SwiftUI + WebKit + PDFKit 交互与状态管理调整。
- 预期用户影响：词表定位效率提升；原文打开过程可理解、可恢复，减少“无响应/打不开”的挫败感。
