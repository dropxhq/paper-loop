## MODIFIED Requirements

### Requirement: 导入状态异步返回
系统 SHALL 在导入过程中通过本地 async pipeline 提供进度状态，无需后端 HTTP 轮询。导入总时长 SHALL 不超过 120 秒（含 LLM 并发调用）。

#### Scenario: 正常导入流程
- **WHEN** 导入请求发出
- **THEN** ImportView 依次切换状态：`parsing`（抓取 HTML/PDF）→ `generatingCards`（LLM 批量生成）→ `done`，进度通过已有 `ImportState` 枚举在 UI 反映，无需网络轮询

#### Scenario: API Key 未配置
- **WHEN** 用户点击"导入论文"但 LLM API Key 未设置
- **THEN** ImportState 立即设为 `failed`，提示引导用户前往"我的"页设置 Key

## REMOVED Requirements

### Requirement: 导入状态异步返回（后端 job 轮询版）
**Reason**: 后端已移除，不再需要通过 jobId 轮询远程服务器状态
**Migration**: 改用本地 async pipeline，直接通过 Swift `async/await` 更新 `ImportState`

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
