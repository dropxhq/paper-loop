## ADDED Requirements

### Requirement: 导入前检测重复 arxivId
系统 SHALL 在用户触发导入时，先从本地 SwiftData 查询是否存在 `arxivId` 相同的 Paper。若存在，SHALL 弹出操作表（ActionSheet）而非直接开始导入。

#### Scenario: 首次导入某论文
- **WHEN** 用户输入 arXiv URL 并点击导入，本地无该 arxivId 的 Paper
- **THEN** 正常执行导入流程，无任何额外提示

#### Scenario: 重复导入同一论文
- **WHEN** 用户输入已存在的 arXiv URL 并点击导入
- **THEN** 弹出操作表，标题说明该论文已存在，提供三个操作选项

### Requirement: 重复导入操作表提供三个选项
操作表 SHALL 包含以下三个选项：
1. **查看已有词卡** —— 跳转到该 Paper 的 `PaperDetailView`，取消导入
2. **合并** —— 执行导入，将新生成的词卡追加到已有 Paper（以 `term.lowercased()` 去重，不插入已有 term）
3. **替换** —— 删除已有 Paper 及其全部 Card，重新执行导入

#### Scenario: 用户选择查看已有词卡
- **WHEN** 操作表中用户点击"查看已有词卡"
- **THEN** 导入流程取消，界面跳转到该 Paper 的 PaperDetailView

#### Scenario: 用户选择合并
- **WHEN** 操作表中用户点击"合并"
- **THEN** 导入流程正常执行，完成后新词卡追加到已有 Paper，已存在的同 term（不区分大小写）词卡不重复插入

#### Scenario: 用户选择替换
- **WHEN** 操作表中用户点击"替换"
- **THEN** 已有 Paper 及其全部 Card 被删除（cascade），导入流程正常执行，生成全新词卡

#### Scenario: 用户取消操作表
- **WHEN** 操作表中用户点击取消或滑动关闭
- **THEN** 导入流程取消，界面保持不变
