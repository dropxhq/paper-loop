import SwiftUI
import SwiftData
import AVFoundation

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.nextReviewAt)
    private var allCards: [Card]

    private var dueCards: [Card] {
        let now = Date()
        return allCards.filter { $0.nextReviewAt <= now }
    }

    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var flipDegrees = 0.0
    @State private var navigateToSource: Card?
    @AppStorage("ttsVoiceBannerDismissed") private var ttsVoiceBannerDismissed = false
    @AppStorage("dashscopeTTSSpeaker") private var dashScopeSpeaker = DashScopeVoiceType.defaultSpeaker
    @State private var isSpeaking = false
    @State private var showTTSSettings = false

    private let synthesizer = AVSpeechSynthesizer()
    private let bestVoice: AVSpeechSynthesisVoice? = ReviewView.bestEnglishVoice()

    /// Whether the best available voice is only compact/default quality
    private var voiceIsLowQuality: Bool {
        guard let voice = bestVoice else { return true }
        if #available(iOS 17, *) {
            return voice.quality == .default
        }
        return voice.quality == .default
    }

    // MARK: - TTS Voice Selection

    private static func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }
        if #available(iOS 16, *) {
            if let premium = voices.first(where: { $0.quality == .premium }) { return premium }
            if let enhanced = voices.first(where: { $0.quality == .enhanced }) { return enhanced }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    private var resolvedDashScopeApiKey: String {
        if let keychainKey = KeychainHelper.read(key: "tts_api_key"), !keychainKey.isEmpty { return keychainKey }
        if let legacyAppStorage = UserDefaults.standard.string(forKey: "dashscopeTTSApiKey"), !legacyAppStorage.isEmpty { return legacyAppStorage }
        if let legacyKey = UserDefaults.standard.string(forKey: "doubaoTTSApiKey"), !legacyKey.isEmpty { return legacyKey }
        return ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Group {
                    if dueCards.isEmpty {
                        emptyStateView
                    } else {
                        reviewCardView
                    }
                }
            }
            .navigationTitle("复习")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $navigateToSource) { card in
                SourceDetailView(card: card)
            }
            .sheet(isPresented: $showTTSSettings) {
                TTSSettingsSheet()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)
            Text("今日复习已完成")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("继续保持！")
                .foregroundStyle(Theme.textMuted)
        }
    }

    // MARK: - Card View

    private var reviewCardView: some View {
        VStack(spacing: 0) {
            Text("\(currentIndex + 1) / \(dueCards.count)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 16)

            Spacer()

            ZStack {
                cardFront
                    .opacity(showAnswer ? 0 : 1)
                cardBack
                    .opacity(showAnswer ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.4), value: flipDegrees)

            Spacer()

            if showAnswer {
                ratingBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
            } else {
                revealButton
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Card Front

    private var cardFront: some View {
        let card = dueCards[currentIndex]
        return VStack(spacing: 16) {
            cardTypeLabel(card.type)
            Text(card.term)
                .font(Font.custom("Georgia", size: 30))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            // Quote box (source sentence preview)
            if let sourceSentence = card.occurrences.last?.sourceSentence, !sourceSentence.isEmpty {
                Text(sourceSentence)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
            }
            HStack(spacing: 8) {
                Button {
                    speak(card.type == .sentence ? (card.occurrences.last?.sourceSentence ?? card.term) : card.term)
                } label: {
                    HStack(spacing: 6) {
                        if isSpeaking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSpeaking ? "加载中..." : (card.type == .sentence ? "播放整句" : "播放发音"))
                    }
                }
                .buttonStyle(ChipButtonStyle())
                .disabled(isSpeaking)
            }
            let dashScopeEnabled = !resolvedDashScopeApiKey.isEmpty
            if !dashScopeEnabled && voiceIsLowQuality && !ttsVoiceBannerDismissed {
                ttsQualityBanner
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .paperCardStyle()
        .padding(.horizontal, 14)
    }

    // MARK: - Card Back

    private var cardBack: some View {
        let card = dueCards[currentIndex]
        return VStack(alignment: .leading, spacing: 12) {
            cardTypeLabel(card.type)
            Text(card.term)
                .font(Font.custom("Georgia", size: 22).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Divider()
                .overlay(Theme.line)
            if !card.zhHint.isEmpty {
                Text(card.zhHint)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textMuted)
            }
            if let sourceSentence = card.occurrences.last?.sourceSentence, !sourceSentence.isEmpty {
                Text(sourceSentence)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
            }
            if let paper = card.occurrences.last?.paper {
                Text("来源：\(paper.title)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Button("回到原文") {
                    navigateToSource = card
                }
                .buttonStyle(ChipButtonStyle(filled: true))

                Button {
                    speak(card.term)
                } label: {
                    HStack(spacing: 6) {
                        if isSpeaking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSpeaking ? "加载中..." : "播放发音")
                    }
                }
                .buttonStyle(ChipButtonStyle())
                .disabled(isSpeaking)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCardStyle()
        .padding(.horizontal, 14)
    }

    // MARK: - Controls

    private var revealButton: some View {
        Button("显示答案") {
            withAnimation {
                flipDegrees = 180
                showAnswer = true
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var ratingBar: some View {
        HStack(spacing: 8) {
            ForEach(ReviewRating.allCases, id: \.rawValue) { rating in
                Button(rating.label) {
                    submitRating(rating)
                }
                .buttonStyle(ReviewRatingButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func submitRating(_ rating: ReviewRating) {
        let card = dueCards[currentIndex]
        ReviewScheduler.schedule(card: card, rating: rating)
        let log = ReviewLog(card: card, rating: rating.rawValue)
        modelContext.insert(log)

        withAnimation {
            flipDegrees = 0
            showAnswer = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if currentIndex < dueCards.count - 1 {
                currentIndex += 1
            } else {
                currentIndex = 0
            }
        }
    }

    private func speak(_ text: String) {
        if !resolvedDashScopeApiKey.isEmpty {
            isSpeaking = true
            Task {
                do {
                    try await DashScopeTTSService.shared.speak(
                        text: text,
                        apiKey: resolvedDashScopeApiKey,
                        speaker: dashScopeSpeaker
                    )
                } catch {
                    // DashScope 失败时降级到系统 TTS
                    await MainActor.run { speakWithSystem(text) }
                }
                await MainActor.run { isSpeaking = false }
            }
        } else {
            speakWithSystem(text)
        }
    }

    private func speakWithSystem(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice
        synthesizer.speak(utterance)
    }

    // MARK: - TTS Quality Banner

    private var ttsQualityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            Text("配置 DashScope TTS Key 可获得更自然的发音")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            Spacer()
            Button("配置") {
                showTTSSettings = true
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.primary)
            Button {
                ttsVoiceBannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
    }

    // MARK: - Card Type Label

    private func cardTypeLabel(_ type: CardType) -> some View {
        let (label, color): (LocalizedStringKey, Color) = switch type {
        case .word: ("单词", Theme.primary)
        case .phrase: ("术语", Color(red: 0.5, green: 0.3, blue: 0.7))
        case .sentence: ("例句", Color(red: 0.8, green: 0.45, blue: 0.1))
        }
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
