## 1. 后端：词卡抽取过滤优化

- [x] 1.1 在 `extractor.py` 中添加 `_is_valid_term(term: str) -> bool` 过滤函数，实现 6 条过滤规则（非 ASCII、数字开头、LaTeX 字符、长度 < 4、短语含非法词、短语 > 5 词）
- [x] 1.2 在 `extract_candidates` 中对所有 NER 候选和 AWL 候选应用 `_is_valid_term` 过滤
- [x] 1.3 移除 RAKE 管道（删除 `_rake` 初始化和调用代码，移除 `rake_nltk` import）
- [x] 1.4 单词类型 term 改存 `token.lemma_.lower()`；短语类型保持原文不变
- [x] 1.5 更新 `pyproject.toml` 移除 `rake_nltk` 依赖（如存在）
- [ ] 1.6 手动测试：用一篇含数学公式的论文 PDF 验证过滤效果，确认无公式碎片词卡产生

## 2. iOS：TTS 声音质量优选

- [x] 2.1 在 `ReviewView.swift` 中新增 `bestEnglishVoice() -> AVSpeechSynthesisVoice?` 私有方法，按 `.premium > .enhanced > .default` 枚举选音
- [x] 2.2 将 `speak()` 方法改用 `bestEnglishVoice()` 返回的声音
- [x] 2.3 添加 `@AppStorage("ttsVoiceBannerDismissed")` 状态变量
- [x] 2.4 在词卡正面（`cardFront`）底部添加条件性 banner view：当最优声音为 default 级别且 banner 未被关闭时显示
- [x] 2.5 Banner 包含说明文字和"前往设置"按钮（`UIApplication.open(URL(string: UIApplication.openSettingsURLString)!)`），以及关闭按钮（设置 `@AppStorage` 为 true）

## 3. iOS：重复导入去重

- [x] 3.1 在 `ImportView.swift` 中新增 `extractArxivId(from url: String) -> String?` 辅助方法，用正则从输入 URL 提取 arxivId
- [x] 3.2 在 `startImport()` 中导入前先 fetch SwiftData，查询 `arxivId` 是否已存在
- [x] 3.3 若已存在，弹出 `confirmationDialog`（或 ActionSheet）显示三个选项：查看已有词卡 / 合并 / 替换
- [x] 3.4 实现"查看已有词卡"分支：dismiss 对话框并 navigate 到 `PaperDetailView`
- [x] 3.5 实现"替换"分支：`modelContext.delete(existingPaper)` 后继续正常导入流程
- [x] 3.6 实现"合并"分支：正常导入后，在 `saveAndNavigate` 中以 `term.lowercased()` 为 key 跳过已有词卡插入，新词卡 attach 到已有 Paper（不新建 Paper）

## 4. iOS：Paper 管理

- [x] 4.1 新建 `Views/PaperDetailView.swift`，接收 `paper: Paper` 参数，展示论文标题、arxivId、导入时间
- [x] 4.2 `PaperDetailView` 中用 `LazyVStack` + `VocabRowView` 展示 `paper.cards`（按 term 排序）
- [x] 4.3 `PaperDetailView` 底部添加"重新导入"按钮，触发替换导入逻辑（复用 3.5 分支）
- [x] 4.4 `PaperDetailView` 中词卡行点击跳转 `SourceDetailView`（复用 VocabView 的 NavigationLink 方式）
- [x] 4.5 在 `ProfileView.swift` 中为论文列表的 `PaperRowView` 包裹 `NavigationLink(destination: PaperDetailView(paper: paper))`
- [x] 4.6 在 `ProfileView.swift` 的论文列表行添加 `.swipeActions { Button("删除", role: .destructive) { modelContext.delete(paper) } }`
- [x] 4.7 将 `PaperDetailView` 注册为 `ImportView` 去重流程的导航目标（3.4 分支跳转）
