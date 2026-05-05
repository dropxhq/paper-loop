## ADDED Requirements

### Requirement: LLM API Key 安全存储
系统 SHALL 使用 iOS Keychain（`Security.framework`）存储 LLM API Key，不得明文写入 UserDefaults、文件或代码。

#### Scenario: 首次保存 Key
- **WHEN** 用户在设置页输入 API Key 并点击保存
- **THEN** 系统将 Key 写入 Keychain，UI 显示保存成功提示

#### Scenario: 读取已存 Key
- **WHEN** 导入流程或设置页加载
- **THEN** 系统从 Keychain 读取 Key，Key 内容在 UI 中以掩码（`sk-xxx...xxx`）形式展示

### Requirement: LLM baseURL 和模型可配置
系统 SHALL 在设置页提供 baseURL 输入框（`@AppStorage`），留空时使用默认值 `https://dashscope.aliyuncs.com/compatible-mode/v1`；模型名称 SHALL 默认为 `deepseek-v4-flash`，可通过设置修改。

#### Scenario: 使用默认 baseURL
- **WHEN** 用户未填写 baseURL
- **THEN** 系统使用 `https://dashscope.aliyuncs.com/compatible-mode/v1` 发起 LLM 调用

#### Scenario: 用户自定义 baseURL
- **WHEN** 用户填写自定义 baseURL（如 OpenAI 官方或自建兼容服务）
- **THEN** 系统使用该 URL 发起 LLM 调用，格式为 `{baseURL}/chat/completions`

### Requirement: ProfileView 展示 LLM 设置入口
系统 SHALL 在 ProfileView 中新增"AI 设置"card，包含 LLM API Key 输入、baseURL 输入和当前 TTS Key 的统一入口；SHALL 在 DashScope 用户场景下提示 Key 可共用。

#### Scenario: 设置页展示
- **WHEN** 用户进入"我的"页
- **THEN** 页面显示"AI 设置"card，其中 LLM 区域包含 API Key 字段（掩码）、baseURL 字段；DashScope 场景下显示提示文字"DashScope 用户：TTS 与 LLM 可使用同一 Key"

#### Scenario: 导航到 TTS 设置
- **WHEN** 用户点击 TTS 设置按钮
- **THEN** 系统展示现有 TTSSettingsSheet（行为不变）
