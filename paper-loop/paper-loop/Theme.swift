import SwiftUI
import UIKit

// MARK: - Design Tokens (matches paper_vocab_iphone_mvp_v2.html)

enum Theme {
    // Colors — adaptive light/dark
    // Light:  warm cream palette (#f6f2ea, #fffdfa, #efe6da …)
    // Dark:   warm dark palette  (#1c1a15, #252219, #2e2b22 …)

    static let bg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.102, blue: 0.082, alpha: 1) // #1c1a15
            : UIColor(red: 0.965, green: 0.949, blue: 0.918, alpha: 1) // #f6f2ea
    })

    static let surface = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.145, green: 0.133, blue: 0.098, alpha: 1) // #252219
            : UIColor(red: 1.000, green: 0.996, blue: 0.980, alpha: 1) // #fffdfa
    })

    static let surface2 = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.180, green: 0.169, blue: 0.133, alpha: 1) // #2e2b22
            : UIColor(red: 0.937, green: 0.902, blue: 0.855, alpha: 1) // #efe6da
    })

    static let line = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.12)
            : UIColor(red: 0.129, green: 0.114, blue: 0.094, alpha: 0.10)
    })

    static let textPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.941, green: 0.925, blue: 0.878, alpha: 1) // #f0ece0
            : UIColor(red: 0.125, green: 0.114, blue: 0.094, alpha: 1) // #201d18
    })

    static let textMuted = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.541, green: 0.510, blue: 0.459, alpha: 1) // #8a8275
            : UIColor(red: 0.435, green: 0.404, blue: 0.365, alpha: 1) // #6f675d
    })

    static let primary = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.082, green: 0.569, blue: 0.553, alpha: 1) // #15918d
            : UIColor(red: 0.047, green: 0.408, blue: 0.396, alpha: 1) // #0c6865
    })

    static let primarySoft = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.106, green: 0.216, blue: 0.204, alpha: 1) // #1b3734
            : UIColor(red: 0.863, green: 0.910, blue: 0.898, alpha: 1) // #dce8e5
    })

    // Corner radii
    static let r16: CGFloat = 16
    static let r18: CGFloat = 18
    static let r24: CGFloat = 24

    // Shadow
    static let cardShadow = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.30)
            : UIColor(white: 0, alpha: 0.08)
    })
}

// MARK: - ViewModifiers

struct PaperCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r24))
            .overlay(RoundedRectangle(cornerRadius: Theme.r24).stroke(Theme.line, lineWidth: 1))
            .shadow(color: Theme.cardShadow, radius: 13, x: 0, y: 10)
    }
}

struct ListItemStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
            .overlay(RoundedRectangle(cornerRadius: Theme.r18).stroke(Theme.line, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.primary.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
    }
}

struct ChipButtonStyle: ButtonStyle {
    var filled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(filled ? Theme.primary : Theme.surface2)
            .foregroundStyle(filled ? .white : Theme.textPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(filled ? Color.clear : Theme.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct ReviewRatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.surface2.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - Convenience Extensions

extension View {
    func paperCardStyle() -> some View {
        modifier(PaperCardStyle())
    }

    func listItemStyle() -> some View {
        modifier(ListItemStyle())
    }
}

// MARK: - Reusable Components

struct EyebrowBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.primarySoft)
            .foregroundStyle(Theme.primary)
            .clipShape(Capsule())
    }
}

struct SectionHeader: View {
    let title: String
    let badge: String?

    init(_ title: String, badge: String? = nil) {
        self.title = title
        self.badge = badge
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let badge {
                EyebrowBadge(text: badge)
            }
        }
    }
}

struct MiniStatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
        .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
    }
}
