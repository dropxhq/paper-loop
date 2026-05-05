## ADDED Requirements

### Requirement: 论文列表支持滑动删除
`ProfileView` 的论文列表中每行 SHALL 支持左滑显示删除按钮，点击后删除该 Paper 及其全部关联 Card（SwiftData cascade）。

#### Scenario: 用户滑动删除论文
- **WHEN** 用户在 ProfileView 论文列表中左滑某行并点击"删除"
- **THEN** 该 Paper 从 SwiftData 中删除，其全部 Card 和 ReviewLog 联级删除，列表刷新

#### Scenario: 删除后词卡列表更新
- **WHEN** Paper 被删除后用户切换到 VocabView
- **THEN** 该论文的所有词卡不再出现在词表中

### Requirement: 论文行可点击进入详情页
`ProfileView` 的论文列表中每行 SHALL 可点击，跳转到 `PaperDetailView`。

#### Scenario: 用户点击论文行
- **WHEN** 用户在 ProfileView 论文列表中点击某论文行
- **THEN** 界面跳转到该 Paper 的 PaperDetailView

### Requirement: PaperDetailView 展示论文信息与词卡列表
新增 `PaperDetailView` SHALL 展示：
- 论文标题、arxiv ID、导入时间
- 该论文全部词卡列表（复用 `VocabRowView`）
- 底部"重新导入"按钮，点击触发替换导入流程

#### Scenario: 进入 PaperDetailView
- **WHEN** 用户跳转到某 Paper 的 PaperDetailView
- **THEN** 页面展示论文元信息及该论文的所有词卡，使用 VocabRowView 样式

#### Scenario: 点击重新导入
- **WHEN** 用户在 PaperDetailView 点击"重新导入"按钮
- **THEN** 触发替换导入流程（删除旧 Paper + Cards，重新导入该论文）

#### Scenario: PaperDetailView 作为去重跳转落点
- **WHEN** 去重操作表中用户选择"查看已有词卡"
- **THEN** 界面跳转到对应 Paper 的 PaperDetailView

### Requirement: PaperDetailView 支持词卡跳转到原文
`PaperDetailView` 的词卡列表中每行 SHALL 可点击，跳转到 `SourceDetailView`（与 VocabView 行为一致）。

#### Scenario: 点击词卡跳转原文
- **WHEN** 用户在 PaperDetailView 中点击某词卡行
- **THEN** 界面跳转到该词卡的 SourceDetailView
