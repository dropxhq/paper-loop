## ADDED Requirements

### Requirement: 获取 arXiv 论文元数据
系统 SHALL 通过 arXiv Atom feed（`https://export.arxiv.org/abs/{id}`）获取论文标题和摘要，无需后端中转。

#### Scenario: 元数据获取成功
- **WHEN** 用户提交合法 arXiv ID
- **THEN** 系统通过 URLSession 请求 arXiv Atom XML，解析 `<title>` 和 `<summary>` 字段，返回 Paper 元数据对象

#### Scenario: 元数据获取失败
- **WHEN** arXiv 接口不可达或超时（>15 秒）
- **THEN** 系统以 arXiv ID 作为标题兜底，继续进行正文抓取，不终止导入流程

### Requirement: HTML 正文抓取与段落提取（客户端）
系统 SHALL 在 iOS 客户端直接请求 `arxiv.org/html/{id}`，使用 SwiftSoup 解析 `<section>`、`<h1-4>`、`<p>` 元素，提取段落文本和 element ID。

#### Scenario: HTML 版本可用
- **WHEN** arXiv HTML 返回 200
- **THEN** SwiftSoup 提取所有 `<p>` 元素（文字长度 ≥30），记录所属 section 标题和 element ID，返回段落数组

#### Scenario: HTML 版本不可用
- **WHEN** arXiv HTML 返回非 200 或网络超时
- **THEN** 系统自动降级至 PDFKit 解析路径

### Requirement: PDF 正文提取（PDFKit，客户端兜底）
系统 SHALL 在 HTML 不可用时，通过 URLSession 下载 arXiv PDF，用 PDFKit（`PDFDocument`/`PDFPage.string`）提取文字，按页码记录 anchor。

#### Scenario: PDF 有文字层
- **WHEN** PDFKit 能从 PDF 提取非空文字
- **THEN** 系统按页分段（≥30 字符），每段附带 `{page}` anchor，返回段落数组

#### Scenario: PDF 无文字层
- **WHEN** PDFKit 提取结果为空
- **THEN** 系统返回错误，提示"该论文为扫描版，暂不支持"
