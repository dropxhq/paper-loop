import SwiftUI
import SwiftData
import AVFoundation

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Card> { $0.nextReviewAt <= Date() },
           sort: \Card.nextReviewAt)
    private var dueCards: [Card]

    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var flipDegrees = 0.0
    @State private var navigateToSource: Card?

    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            Group {
                if dueCards.isEmpty {
                    emptyStateView
                } else {
                    reviewCardView
                }
            }
            .navigationTitle("复习")
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
                .foregroundStyle(.green)
            Text("今日复习已完成")
                .font(.title2.bold())
            Text("继续保持！")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Card View

    private var reviewCardView: some View {
        VStack(spacing: 0) {
            Text("\(currentIndex + 1) / \(dueCards.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top)

            Spacer()

            ZStack {
                cardFront
                    .opacity(showAnswer ? 0 : 1)
                cardBack
                    .opacity(showAnswer ? 1 : 0)
                    .rotation3DEffect(.degrees(showAnswer ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
            .animation(.easeInOut(duration: 0.4), value: flipDegrees)

            Spacer()

            if showAnswer {
                ratingBar
                    .padding(.bottom, 24)
            } else {
                revealButton
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Card Front

    private var cardFront: some View {
        let card = dueCards[currentIndex]
        return VStack(spacing: 16) {
            cardTypeLabel(card.type)
            Text(card.term)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Button {
                speak(card.type == .sentence ? card.sourceSentence : card.term)
            } label: {
                Label(card.type == .sentence ? "播放整句" : "播放发音",
                      systemImage: "speaker.wave.2")
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(.background).shadow(radius: 6))
        .padding(.horizontal)
    }

    // MARK: - Card Back

    private var cardBack: some View {
        let card = dueCards[currentIndex]
        return VStack(alignment: .leading, spacing: 12) {
            cardTypeLabel(card.type)
            Text(card.term)
                .font(.title2.bold())
            Divider()
            Text(card.zhHint)
                .font(.body)
                .foregroundStyle(.secondary)
            if !card.sourceSentence.isEmpty {
                Text(card.sourceSentence)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.primary.opacity(0.8))
            }
            if let paper = card.paper {
                HStack {
                    Image(systemName: "doc.text")
                    Text(paper.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            Button {
                navigateToSource = card
            } label: {
                Label("回到原文", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(.background).shadow(radius: 6))
        .padding(.horizontal)
    }

    // MARK: - Controls

    private var revealButton: some View {
        Button("显示答案") {
            withAnimation {
                flipDegrees = 180
                showAnswer = true
            }
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
    }

    private var ratingBar: some View {
        HStack(spacing: 8) {
            ForEach(ReviewRating.allCases, id: \.rawValue) { rating in
                Button(rating.label) {
                    submitRating(rating)
                }
                .buttonStyle(.bordered)
                .font(.callout)
            }
        }
        .padding(.horizontal)
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
        case .word: ("单词", .blue)
        case .phrase: ("术语", .purple)
        case .sentence: ("例句", .orange)
        }
        return Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    ReviewView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
