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

    private let synthesizer = AVSpeechSynthesizer()

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
            if !card.sourceSentence.isEmpty {
                Text(card.sourceSentence)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.259, green: 0.239, blue: 0.208))
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
            }
            HStack(spacing: 8) {
                Button(card.type == .sentence ? "播放整句" : "播放发音") {
                    speak(card.type == .sentence ? card.sourceSentence : card.term)
                }
                .buttonStyle(ChipButtonStyle())
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
            if !card.sourceSentence.isEmpty {
                Text(card.sourceSentence)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.259, green: 0.239, blue: 0.208))
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
            }
            if let paper = card.paper {
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

                Button("播放发音") {
                    speak(card.term)
                }
                .buttonStyle(ChipButtonStyle())
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func cardTypeLabel(_ type: CardType) -> some View {
        let (label, color): (String, Color) = switch type {
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
