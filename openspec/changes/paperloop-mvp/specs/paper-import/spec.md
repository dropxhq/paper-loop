## ADDED Requirements

### Requirement: 解析 arXiv 链接提取 paper_id
系统 SHALL 接受标准 arXiv 链接格式（`arxiv.org/abs/{id}`、`arxiv.org/pdf/{id}`），提取 paper_id 并规范化。

#### Scenario: 标准 abs 链接
- **WHEN** 用户输入 `https://arxiv.org/abs/1706.03762`
- **THEN** 系统提取 paper_id 为 `1706.03762`

#### Scenario: PDF 链接格式
- **WHEN** 用户输入 `https://arxiv.org/pdf/2310.06825`
- **THEN** 系统提取 paper_id 为 `2310.06825`

#### Scenario: 无效链接
- **WHEN** 用户输入非 arXiv URL
- **THEN** 系统返回错误，提示"仅支持 arXiv 链接"

### Requirement: HTML 优先提取正文内容
系统 SHALL 优先尝试 `arxiv.org/html/{id}` 获取 HTML 版本，解析段落并保留 element ID 作为 anchor。

#### Scenario: HTML 版本可用
- **WHEN** arXiv HTML 版本存在且可访问
- **THEN** 系统解析 `<section>` 和 `<p>` 元素，提取文本和 element ID，返回段落列表

#### Scenario: HTML 版本不存在
- **WHEN** arXiv HTML 版本返回 404 或解析失败
- **THEN** 系统自动降级至 PDF 解析路径，不向用户暴露错误

### Requirement: PDF 兜底解析
系统 SHALL 在 HTML 不可用时下载 PDF 并用 PyMuPDF 提取文本，保留页码和 bbox 坐标。

#### Scenario: PDF 文字层正常
- **WHEN** PDF 含有 text layer（非扫描件）
- **THEN** 系统返回段落列表，每段附带 `{page, bbox}` anchor

#### Scenario: PDF 无文字层
- **WHEN** PDF 为扫描图片
- **THEN** 系统返回错误，提示"该论文为扫描版，暂不支持"

### Requirement: 导入状态异步返回
系统 SHALL 在导入耗时超过 2 秒时提供进度状态，导入总时长 SHALL 不超过 30 秒。

#### Scenario: 正常导入流程
- **WHEN** 导入请求发出
- **THEN** 接口立即返回 `{ status: "processing", jobId }` 并异步处理，iOS 端轮询状态
