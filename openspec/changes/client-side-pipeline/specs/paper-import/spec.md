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
