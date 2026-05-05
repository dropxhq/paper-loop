import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var papers: [Paper]
    @Query private var cards: [Card]
    @Query private var reviewLogs: [ReviewLog]

    @State private var showTTSSettings = false
    @State private var llmAPIKeyInput = ""
    @State private var llmBaseURLInput = ""
    @State private var llmModelInput = ""
    @State private var showAPIKeySaved = false
    @AppStorage("llm_base_url") private var savedBaseURL = ""
    @AppStorage("llm_model") private var savedModel = ""

    private var maskedKey: String {
        guard let key = KeychainHelper.read(key: "llm_api_key"), !key.isEmpty else {
            return ""
        }
        if key.count <= 8 { return String(repeating: "•", count: key.count) }
        let prefix = key.prefix(5)
        let suffix = key.suffix(4)
        return "\(prefix)•••\(suffix)"
    }

    private var todayReviews: Int {
        let calendar = Calendar.current
        return reviewLogs.filter { calendar.isDateInToday($0.reviewedAt) }.count
    }

    private var masteredCards: Int {
        cards.filter { $0.repetitions >= 3 }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // Stats card
                        VStack(spacing: 10) {
                            SectionHeader("学习统计")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                MiniStatBox(value: "\(cards.count)", label: "词卡总数")
                                MiniStatBox(value: "\(todayReviews)", label: "今日复习")
                                MiniStatBox(value: "\(masteredCards)", label: "已掌握")
                            }
                        }
                        .padding(14)
                        .paperCardStyle()

                        // Papers card
                        VStack(spacing: 0) {
                            SectionHeader("已导入论文", badge: "\(papers.count)")
                                .padding(.bottom, 10)
                            if papers.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Theme.textMuted)
                                    Text("还没有导入论文")
                                        .foregroundStyle(Theme.textMuted)
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                ForEach(papers.sorted(by: { $0.importedAt > $1.importedAt })) { paper in
                                    NavigationLink(destination: PaperDetailView(paper: paper)) {
                                        PaperRowView(paper: paper)
                                            .padding(.top, paper == papers.sorted(by: { $0.importedAt > $1.importedAt }).first ? 0 : 8)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(paper)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .paperCardStyle()

                        // TTS card
                        VStack(spacing: 0) {
                            SectionHeader("语音朗读")
                                .padding(.bottom, 10)
                            Button {
                                showTTSSettings = true
                            } label: {
                                TTSConfigRow()
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .paperCardStyle()
                        .sheet(isPresented: $showTTSSettings) {
                            TTSSettingsSheet()
                        }

                        // AI Settings card
                        VStack(spacing: 0) {
                            SectionHeader("AI 设置")
                                .padding(.bottom, 10)

                            // API Key field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("LLM API Key")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.textMuted)
                                SecureField("输入 API Key", text: $llmAPIKeyInput)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 42)
                                    .background(Theme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
                                if !maskedKey.isEmpty {
                                    Text("当前：\(maskedKey)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textMuted)
                                }
                                Text("DashScope 用户：语音朗读与卡片生成可使用同一 Key")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textMuted)
                                    .lineSpacing(3)
                            }
                            .padding(.bottom, 10)

                            // Base URL field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Base URL（留空使用默认）")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.textMuted)
                                TextField("https://dashscope.aliyuncs.com/compatible-mode/v1", text: $llmBaseURLInput)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 42)
                                    .background(Theme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
                            }
                            .padding(.bottom, 10)

                            // Model field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("模型（留空使用默认 deepseek-v4-flash）")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.textMuted)
                                TextField("deepseek-v4-flash", text: $llmModelInput)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textPrimary)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 42)
                                    .background(Theme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
                            }
                            .padding(.bottom, 10)

                            Button {
                                saveAISettings()
                            } label: {
                                Text(showAPIKeySaved ? "已保存 ✓" : "保存设置")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(14)
                        .paperCardStyle()
                        .onAppear {
                            llmBaseURLInput = savedBaseURL
                            llmModelInput = savedModel
                        }

                        // Settings card
                        VStack(spacing: 0) {
                            SectionHeader("设置")
                                .padding(.bottom, 10)
                            settingsRow(title: "字体大小", subtitle: "正文 15pt")
                            settingsRow(title: "朗读速度", subtitle: "正常")
                            settingsRow(title: "深色模式", subtitle: "跟随系统")
                        }
                        .padding(14)
                        .paperCardStyle()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func saveAISettings() {
        if !llmAPIKeyInput.isEmpty {
            KeychainHelper.save(key: "llm_api_key", value: llmAPIKeyInput)
            llmAPIKeyInput = ""
        }
        savedBaseURL = llmBaseURLInput
        savedModel = llmModelInput
        showAPIKeySaved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showAPIKeySaved = false
        }
    }

    private func settingsRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
        .overlay(RoundedRectangle(cornerRadius: Theme.r18).stroke(Theme.line, lineWidth: 1))
        .padding(.top, 4)
    }
}

// MARK: - Subviews

private struct PaperRowView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(paper.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(paper.arxivId)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            if !paper.occurrences.isEmpty {
                let cardCount = Set(paper.occurrences.compactMap { $0.card?.id }).count
                Text("\(cardCount) 张词卡")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
        .overlay(RoundedRectangle(cornerRadius: Theme.r18).stroke(Theme.line, lineWidth: 1))
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Paper.self, Card.self, Occurrence.self, ReviewLog.self], inMemory: true)
}

// MARK: - TTS Config Row

private struct TTSConfigRow: View {
    @AppStorage("dashscopeTTSApiKey") private var apiKey = ""

    private var isConfigured: Bool { !apiKey.isEmpty }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DashScope 语音")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(isConfigured ? "已配置 · 点击修改" : "未配置 · 点击填写 API Key")
                    .font(.system(size: 12))
                    .foregroundStyle(isConfigured ? Theme.primary : Theme.textMuted)
            }
            Spacer()
            if isConfigured {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.primary)
                    .font(.system(size: 16))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
        .overlay(RoundedRectangle(cornerRadius: Theme.r18).stroke(Theme.line, lineWidth: 1))
        .padding(.top, 4)
    }
}

// MARK: - TTS Settings Sheet

struct TTSSettingsSheet: View {
    @AppStorage("dashscopeTTSApiKey") private var apiKey = ""
    @AppStorage("dashscopeTTSSpeaker") private var speaker = DashScopeVoiceType.defaultSpeaker

    @Environment(\.dismiss) private var dismiss
    @State private var draftApiKey = ""
    @State private var draftSpeaker = DashScopeVoiceType.defaultSpeaker
    @State private var testState: TestState = .idle

    private enum TestState {
        case idle, loading, success, failure(String)
    }

    private var currentSpeakers: [(id: String, label: String)] {
        DashScopeVoiceType.speakers
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Intro
                        VStack(alignment: .leading, spacing: 6) {
                            Text("配置 DashScope 语音合成，在复习词卡时使用高质量 AI 发音代替系统 TTS。")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                            Link("前往阿里云百炼获取 API Key →",
                                 destination: URL(string: "https://help.aliyun.com/zh/model-studio/get-api-key")!)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .paperCardStyle()

                        // API Key
                        VStack(spacing: 0) {
                            SectionHeader("API 凭据")
                                .padding(.bottom, 10)
                            apiKeyField
                        }
                        .padding(14)
                        .paperCardStyle()


                        // Voice
                        VStack(spacing: 0) {
                            SectionHeader("音色")
                                .padding(.bottom, 10)
                            VStack(spacing: 6) {
                                ForEach(currentSpeakers, id: \.id) { voice in
                                    selectionRow(label: voice.label, isSelected: draftSpeaker == voice.id) {
                                        draftSpeaker = voice.id
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .paperCardStyle()

                        // Test button
                        VStack(spacing: 8) {
                            Button {
                                testVoice()
                            } label: {
                                HStack(spacing: 6) {
                                    if case .loading = testState {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "play.circle")
                                    }
                                    Text("试听发音")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(draftApiKey.isEmpty)

                            if case .success = testState {
                                Label("朗读成功", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.primary)
                            } else if case .failure(let msg) = testState {
                                Label(msg, systemImage: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("语音朗读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primary)
                }
            }
            .onAppear {
                if !apiKey.isEmpty {
                    draftApiKey = apiKey
                } else if let legacyKey = UserDefaults.standard.string(forKey: "doubaoTTSApiKey"), !legacyKey.isEmpty {
                    draftApiKey = legacyKey
                } else {
                    draftApiKey = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] ?? ""
                }

                if !speaker.isEmpty {
                    draftSpeaker = speaker
                } else if let legacySpeaker = UserDefaults.standard.string(forKey: "doubaoTTSSpeaker"), !legacySpeaker.isEmpty {
                    draftSpeaker = legacySpeaker
                }
            }
        }
    }

    // MARK: - Sub Views

    private var apiKeyField: some View {
        HStack {
            Text("API Key")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 64, alignment: .leading)
            SecureField("粘贴你的 API Key", text: $draftApiKey)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
        .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
    }

    private func selectionRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(12)
            .background(isSelected ? Theme.primarySoft : Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.r18)
                    .stroke(isSelected ? Theme.primary.opacity(0.3) : Theme.line, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func save() {
        apiKey = draftApiKey.trimmingCharacters(in: .whitespaces)
        speaker = draftSpeaker
        dismiss()
    }

    private func testVoice() {
        testState = .loading
        let key = draftApiKey.trimmingCharacters(in: .whitespaces)
        let spk = draftSpeaker
        Task {
            do {
                try await DashScopeTTSService.shared.speak(
                    text: "The quick brown fox jumps over the lazy dog.",
                    apiKey: key,
                    speaker: spk
                )
                await MainActor.run { testState = .success }
            } catch {
                await MainActor.run { testState = .failure(error.localizedDescription) }
            }
        }
    }
}
