## ADDED Requirements

### Requirement: 回链详情页展示
系统 SHALL 在回链详情页展示来源论文信息、原句高亮和前后上下文。

#### Scenario: 查看回链详情
- **WHEN** 用户从卡片点击"回到原文"或"查看上下文"
- **THEN** 展示：论文标题、anchor 位置描述（章节名或页码）、原句（高亮）、前后各 1–2 句上下文

### Requirement: HTML anchor 跳转
系统 SHALL 通过 WKWebView 加载 arXiv HTML 版本并跳转至对应段落，高亮原句。

#### Scenario: HTML 回链跳转
- **WHEN** 卡片 anchor 类型为 `html`，用户点击"打开原文"
- **THEN** 在 App 内打开 WKWebView，加载 `arxiv.org/html/{id}`，页面加载后执行 JS 滚动至 `elementId` 并高亮原句文本

#### Scenario: HTML 加载失败
- **WHEN** 网络不可用或 HTML 版本已失效
- **THEN** 提示"当前网络不可用，无法打开原文"

### Requirement: PDF anchor 跳转
系统 SHALL 通过 PDFKit 打开 PDF 并定位至对应页码，使用文本搜索高亮原句。

#### Scenario: PDF 回链跳转
- **WHEN** 卡片 anchor 类型为 `pdf`，用户点击"打开原文"
- **THEN** 在 App 内打开 PDFView，导航至对应页码，调用 `findString` 定位原句并添加高亮 annotation

#### Scenario: 文本搜索无匹配
- **WHEN** `findString` 未找到原句（如 PDF 文字层损坏）
- **THEN** 仅跳转到对应页码，不添加高亮，提示"已定位到原文页码"

### Requirement: PDF 本地缓存
系统 SHALL 缓存已下载的 PDF 文件，避免重复下载。

#### Scenario: PDF 已缓存
- **WHEN** 同一 paper 的 PDF 已在本地缓存
- **THEN** 直接读取本地文件，不发起网络请求
