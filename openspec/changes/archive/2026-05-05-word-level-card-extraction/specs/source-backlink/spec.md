## MODIFIED Requirements

### Requirement: 回链详情页展示
系统 SHALL 在回链详情页展示来源论文信息、所有 occurrences 列表，每条 occurrence 可单独跳转原文。

#### Scenario: 展示 occurrences 列表
- **WHEN** 用户从卡片点击"回到原文"
- **THEN** 展示所有 occurrences，每条显示：来源论文标题、章节名或页码、原句；条目按导入顺序排列

#### Scenario: 单条 occurrence 跳转原文
- **WHEN** 用户点击某条 occurrence 的"查看上下文"
- **THEN** 打开对应论文的 HTML 或 PDF，跳转至对应段落位置

### Requirement: HTML anchor 跳转
系统 SHALL 通过 WKWebView 加载 arXiv HTML 版本并跳转至对应段落。

#### Scenario: HTML 回链跳转
- **WHEN** occurrence 的 anchor 类型为 `.html`，用户点击"打开原文"
- **THEN** 在 App 内打开 WKWebView，加载 `arxiv.org/html/{id}`，页面加载后执行 JS 滚动至 `elementId`

#### Scenario: HTML 加载失败
- **WHEN** 网络不可用或 HTML 版本已失效
- **THEN** 提示"当前网络不可用，无法打开原文"

### Requirement: PDF anchor 跳转
系统 SHALL 通过 PDFKit 打开 PDF 并定位至对应页码，使用文本搜索定位原句。

#### Scenario: PDF 回链跳转
- **WHEN** occurrence 的 anchor 类型为 `.pdf`，用户点击"打开原文"
- **THEN** 在 App 内打开 PDFView，导航至对应页码，调用 `findString` 定位原句

#### Scenario: 文本搜索无匹配
- **WHEN** `findString` 未找到原句
- **THEN** 仅跳转到对应页码，提示"已定位到原文页码"

### Requirement: PDF 本地缓存
系统 SHALL 缓存已下载的 PDF 文件，避免重复下载。

#### Scenario: PDF 已缓存
- **WHEN** 同一 paper 的 PDF 已在本地缓存
- **THEN** 直接读取本地文件，不发起网络请求
