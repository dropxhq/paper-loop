## ADDED Requirements

### Requirement: 优先使用高质量本地 TTS 声音
系统 SHALL 在初始化时枚举所有可用的 `en-*` 语音，按 `.premium > .enhanced > .default` 优先级选出最佳声音，并缓存供本次会话使用。

#### Scenario: 设备已下载 premium 声音
- **WHEN** 设备安装了 iOS premium neural voice（如 Siri 声音）
- **THEN** 播放发音时使用 premium voice，发音自然流畅

#### Scenario: 设备仅有 enhanced 声音
- **WHEN** 设备未安装 premium 但安装了 enhanced voice
- **THEN** 播放发音时使用 enhanced voice

#### Scenario: 设备仅有 default（compact）声音
- **WHEN** 设备未安装 premium 或 enhanced voice
- **THEN** 播放发音时使用 default voice，并触发引导 banner

### Requirement: 引导用户下载高质量声音
系统 SHALL 在检测到只有 default voice 时，在首次播放时展示一次性提示 banner，引导用户前往系统设置下载 Enhanced 声音包。

#### Scenario: 首次播放且声音质量不足
- **WHEN** 用户首次点击"播放发音"且当前最优声音为 default 级别
- **THEN** 词卡底部展示 banner，内容说明可以下载更好的声音，并提供跳转设置的按钮

#### Scenario: 用户已关闭过 banner
- **WHEN** 用户曾点击过 banner 的关闭按钮（持久化到 `@AppStorage`）
- **THEN** 不再展示 banner，即使声音仍为 default 级别
