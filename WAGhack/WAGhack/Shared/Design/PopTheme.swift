import SwiftUI
import UIKit

/// RakugakiSNSと同じPOPな見た目(黒インクの枠・ずらした影・蛍光ペンの見出し)。
/// 旅の記録・都道府県の一覧・市区町村詳細の読みもの画面と、初訪問の儀式シートのボタンで使う。
/// 地図の上に浮かぶ操作(フッター・ヘッダー)はLiquid Glassのまま、設定画面はiOS標準のままにする。
///
/// RakugakiSNSの紙はクリーム色だが、よりみちでは白い紙にする(ユーザーの希望)。
/// RakugakiSNSはライト固定だが、よりみちは地図のシートに重なってほかの画面と並ぶため、
/// 紙・インク・カードだけダークモードで入れ替える。黄色やミントなどの差し色は明るいまま固定し、
/// その上に載せる文字は`inkOnAccent`(常に濃い色)を使う。
enum Pop {
    static let paper = dynamic(light: 0xFFFFFF, dark: 0x1D1B22)
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
    /// 踏破率のバーの塗り。地図で訪問済みを塗るtealに寄せて、地図と数字を結びつける。
    static let teal = fixed(0x3CC4B4)
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

/// 黒枠とずらした影のボタン。押すと影の方へ沈む。儀式シートの主役の操作だけに使う。
struct PopButtonStyle: ButtonStyle {
    var fill: Color = Pop.yellow
    var foreground: Color = Pop.inkOnAccent
    private static let shadowOffset: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Pop.cornerRadius)
        let offset = configuration.isPressed ? 1 : Self.shadowOffset
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(fill, in: shape)
            .overlay(shape.stroke(Pop.ink, lineWidth: Pop.borderWidth))
            .background(shape.fill(Pop.ink).offset(x: offset, y: offset))
            .offset(x: Self.shadowOffset - offset, y: Self.shadowOffset - offset)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PopButtonStyle {
    /// 黄色い主役のボタン。
    static var pop: PopButtonStyle { PopButtonStyle() }
    /// 主役の横に置く二番手のボタン(閉じるなど)。カードと同じ白にする。
    static var popSecondary: PopButtonStyle { PopButtonStyle(fill: Pop.card, foreground: Pop.ink) }
}

/// 黒枠のカプセルに塗りを詰めた踏破率のバー。読み上げは`ProgressView`と同じく割合で伝える。
struct PopProgressBar: View {
    let fraction: Double
    var fill: Color = Pop.teal
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 12

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        Capsule()
            .fill(Pop.card)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(fill)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Pop.ink, lineWidth: Pop.borderWidth))
            .frame(height: height)
            .accessibilityElement()
            .accessibilityValue(clamped.formatted(.percent.precision(.fractionLength(1))))
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

/// 一覧の1行を、押すと次の画面へ進むカードにする。右端に進む印を付ける。
/// Listの行をカードにするとスワイプや区切り線と見た目がぶつかるため、ScrollViewに並べる前提にしている。
struct PopNavigationCard<Destination: View, Label: View>: View {
    private let shadow: Color
    private let destination: () -> Destination
    private let label: () -> Label

    init(
        shadow: Color = Pop.ink,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.shadow = shadow
        self.destination = destination
        self.label = label
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(Pop.muted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .popCard(shadow: shadow)
            .contentShape(RoundedRectangle(cornerRadius: Pop.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

/// 一覧の区切りの見出しと、その下に添える小さな説明。
struct PopSectionHeader: View {
    let title: String
    var marker: Color = Pop.mint

    var body: some View {
        MarkerHeading(title, size: 19, marker: marker)
            .padding(.top, 8)
    }
}

/// カードの下に添える、仕組みの説明などの小さな注記。
struct PopFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Pop.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
