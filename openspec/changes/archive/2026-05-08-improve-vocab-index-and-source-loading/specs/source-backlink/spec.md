## MODIFIED Requirements

### Requirement: 单条 occurrence 跳转原文
系统 SHALL 在用户点击某条 occurrence 的"查看上下文"后，先展示加载状态，再打开对应论文的 HTML 或 PDF，并定位至对应段落/页码。

#### Scenario: 单条 occurrence 跳转原文
- **WHEN** 用户点击某条 occurrence 的"查看上下文"
- **THEN** 先展示原文加载页面，加载成功后打开对应论文的 HTML 或 PDF 并定位到该 occurrence 对应位置

### Requirement: HTML anchor 跳转
系统 SHALL 通过 WKWebView 加载 arXiv HTML 版本并跳转至对应段落；若 HTML 加载失败，系统 MUST 提供错误提示与可恢复操作。

#### Scenario: HTML 回链跳转
- **WHEN** occurrence 的 anchor 类型为 `.html`，用户点击"打开原文"
- **THEN** 在 App 内打开 WKWebView，加载 `arxiv.org/html/{id}`，页面加载后执行 JS 滚动至 `elementId`

#### Scenario: HTML 加载失败
- **WHEN** 网络不可用、HTML 页面失效或导航失败
- **THEN** 提示加载失败原因，并提供重试与改用 PDF 打开的恢复路径

### Requirement: PDF anchor 跳转
系统 SHALL 通过 PDFKit 打开 PDF 并定位至对应页码，使用文本搜索定位原句；页码语义 MUST 与阅读器索引一致。

#### Scenario: PDF 回链跳转
- **WHEN** occurrence 的 anchor 类型为 `.pdf`，用户点击"打开原文"
- **THEN** 在 App 内打开 PDFView，导航至对应页码，调用 `findString` 定位原句

#### Scenario: 文本搜索无匹配
- **WHEN** `findString` 未找到原句
- **THEN** 系统仍定位到对应页码，并提示"已定位到原文页码"

## ADDED Requirements

### Requirement: 原文阅读统一加载与错误状态
系统 SHALL 为 HTML 与 PDF 原文阅读提供统一的加载中、加载成功、加载失败状态，以避免静默等待与无响应感知。

#### Scenario: 打开原文时显示加载态
- **WHEN** 用户从词表页或复习页触发"回到原文/查看上下文"
- **THEN** 在阅读器可见内容前显示统一加载页面与进度提示

#### Scenario: 加载失败后可重试
- **WHEN** 原文加载失败
- **THEN** 页面展示失败说明与重试入口，用户可在当前路径内完成恢复
