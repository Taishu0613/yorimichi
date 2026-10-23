import SwiftUI
import UIKit

/// RakugakiSNSと同じPOPな見た目(クリーム色の紙・黒インクの枠・ずらした影)。
/// 今は市区町村詳細(みどころ・怪奇・都市伝説)だけで使う。ほかの画面へ広げるときはここに部品を足す。
///
/// RakugakiSNSはライト固定だが、よりみちは地図のシートに重なってほかの画面と並ぶため、
/// 紙・インク・カードだけダークモードで入れ替える。黄色やミントなどの差し色は明るいまま固定し、
/// その上に載せる文字は`inkOnAccent`(常に濃い色)を使う。
enum Pop {
    static let paper = dynamic(light: 0xF8F5EC, dark: 0x1D1B22)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x2A2731)
    /// 枠・影・本文の色。ダークモードでは紙の色に反転して、暗い背景でも枠と影が見えるようにする。
    static let ink = dynamic(light: 0x28252C, dark: 0xF1EDE3)
    static let muted = dynamic(light: 0x65616A, dark: 0xA8A3AD)

    /// 差し色の上に載せる文字。差し色はモードによらず明るいので、常に濃い色にする。
    static let inkOnAccent = fixed(0x28252C)
    static let yellow = fixed(0xFFDF52)
    static let mint = fixed(0xD9F0E4)
    static let pink = fixed(0xF582B6)
    static let purple = fixed(0x5551DF)
    /// 怪奇・都市伝説のカード。モードによらず夜の色にして、みどころと雰囲気を分ける。
    static let night = fixed(0x2D2A3E)
    static let onNight = fixed(0xF8F5EC)

    static let borderWidth: CGFloat = 1.5
    static let cornerRadius: CGFloat = 14

    private static func fixed(_ hex: UInt32) -> Color {
        Color(uiColor: uiColor(hex))
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
        })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// 黒枠とずらした影のカード。影の色でカードの種類を示す。
    func popCard(
        fill: Color = Pop.card,
        shadow: Color = Pop.ink,
        cornerRadius: CGFloat = Pop.cornerRadius,
        shadowOffset: CGFloat = 4
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return background(fill, in: shape)
            .overlay(shape.stroke(Pop.ink, lineWidth: Pop.borderWidth))
            .background(shape.fill(shadow).offset(x: shadowOffset, y: shadowOffset))
    }
}

/// 蛍光ペンを引いたような見出し。文字の大きさはDynamic Typeに合わせて伸び縮みする。
struct MarkerHeading: View {
    let text: String
    let marker: Color
    let foreground: Color
    @ScaledMetric private var size: CGFloat

    init(_ text: String, size: CGFloat = 21, marker: Color = Pop.yellow, foreground: Color = Pop.ink) {
        self.text = text
        self.marker = marker
        self.foreground = foreground
        _size = ScaledMetric(wrappedValue: size, relativeTo: .title2)
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(foreground)
            .background(alignment: .bottom) {
                Capsule()
                    .fill(marker)
                    .frame(height: size * 0.42)
                    .padding(.horizontal, -5)
                    .rotationEffect(.degrees(-1.5))
                    .offset(y: -1)
            }
            .accessibilityAddTraits(.isHeader)
    }
}

/// 状態や分類を示す小さなピル。塗りは差し色だけを使う前提で、文字は常に濃い色にする。
struct PopPill: View {
    let text: String
    var systemImage: String? = nil
    var fill: Color = Pop.yellow

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(text)
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(Pop.inkOnAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(fill, in: Capsule())
        .overlay(Capsule().stroke(Pop.ink, lineWidth: Pop.borderWidth))
    }
}

/// 見出しの横に置く丸いアイコン。カードの種類をひと目で分ける。
struct PopIconBadge: View {
    let systemImage: String
    var fill: Color = Pop.yellow
    var foreground: Color = Pop.inkOnAccent
    @ScaledMetric(relativeTo: .title2) private var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(Pop.ink, lineWidth: Pop.borderWidth))
            .accessibilityHidden(true)
    }
}
