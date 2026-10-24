import SwiftUI
import UIKit

/// RakugakiSNS風のPOPな見た目(蛍光ペンの見出し・ずらした影のカード・ピル)を、よりみちのLiquid Glassになじむよう
/// やわらげたもの。テーマ色は地図の市区町村のポリゴンと同じ`.teal`、黄色はアクセント(蛍光ペン・達成のピル)だけに使う。
///
/// - 枠と影は黒インクではなくテーマ色を薄くして使い、ガラスの軽さを壊さない。
/// - カードとシートの背景は白(ユーザーの希望)。ダークモードでは暗い色に入れ替える。
///   例外として、怪奇・都市伝説のカードだけは夜色にして雰囲気を出す(これもユーザーの希望)。
/// - ボタンはPOPな塗りのボタンを作らず、iOS 26のガラスのボタン(`.glassProminent`/`.glass`)をテーマ色で使う。
/// - 地図に浮かぶ操作(フッター・ヘッダー・現在地バッジ)はガラスのまま、設定画面の操作部品はiOS標準のままにする。
enum Pop {
    static let paper = dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let card = dynamic(light: 0xFFFFFF, dark: 0x2C2C2E)
    /// 本文・見出しの色。
    static let ink = dynamic(light: 0x1F2328, dark: 0xF2F2F7)
    static let muted = dynamic(light: 0x5F6670, dark: 0xA1A6AE)

    /// テーマ色。地図で訪問済みの市区町村を塗る色(`MunicipalityPuzzleLayer`の`.teal`)と同じにして、地図と画面を結びつける。
    static let theme = Color.teal
    /// テーマ色を白に薄く重ねた色。ピルや訪問済みの区の塗りに使う。モードによらず明るいので、上の文字は`inkOnAccent`にする。
    static let themeSoft = fixed(0xDAF1F5)
    /// アクセントの黄色。蛍光ペンの見出しと、達成のピルにだけ使う。
    static let yellow = fixed(0xFFDF52)
    /// 怪奇・都市伝説だけに添える色。みどころ(黄色)と雰囲気を分けるための、アイコンと蛍光ペンだけの差し色。
    static let legend = Color.indigo
    /// 明るい差し色の上に載せる文字。差し色はモードによらず明るいので、常に濃い色にする。
    static let inkOnAccent = fixed(0x1F2328)
    /// 怪奇・都市伝説のカードと、チュートリアルの詩・読み込み画面の背景。モードによらず夜の色にする。
    static let night = fixed(0x2D2A3E)
    /// 夜色の上の文字。
    static let onNight = fixed(0xF8F5EC)

    /// カードの枠。テーマ色を薄くして、白いカードの輪郭だけをやわらかく示す。
    static let border = Color.teal.opacity(0.35)
    /// カードのずらした影の既定の色。
    static let shadow = Color.teal.opacity(0.22)
    static let borderWidth: CGFloat = 1.5
    static let cornerRadius: CGFloat = 18

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
    /// 白いカードに、テーマ色の薄い枠とずらした影を付ける。影の色でカードの種類を示す(既定はテーマ色)。
    func popCard(
        fill: Color = Pop.card,
        shadow: Color = Pop.shadow,
        cornerRadius: CGFloat = Pop.cornerRadius,
        shadowOffset: CGFloat = 4
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background(fill, in: shape)
            .overlay(shape.stroke(Pop.border, lineWidth: Pop.borderWidth))
            .background(shape.fill(shadow).offset(x: shadowOffset, y: shadowOffset))
    }

    /// 主役のボタン。Liquid Glassの塗りのボタンをテーマ色で使う。ラベルは呼び出し側で横幅いっぱいに広げる。
    func popPrimaryButton(tint: Color = Pop.theme) -> some View {
        buttonStyle(.glassProminent)
            .tint(tint)
            .controlSize(.large)
            .font(.headline.weight(.bold))
    }

    /// 主役の横に置く二番手のボタン(閉じる・復元など)。透明なガラスのボタンにする。
    func popSecondaryButton() -> some View {
        buttonStyle(.glass)
            .controlSize(.large)
            .font(.headline.weight(.semibold))
    }
}

/// テーマ色で塗る踏破率のバー。地図のポリゴンと同じ色にして、数字と地図の塗りを結びつける。
/// 読み上げは`ProgressView`と同じく割合で伝える。
struct PopProgressBar: View {
    let fraction: Double
    var fill: Color = Pop.theme
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 10

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        Capsule()
            .fill(Pop.themeSoft.opacity(0.8))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(fill)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Pop.border, lineWidth: 1))
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

/// 状態や分類を示す小さなピル。塗りは明るい差し色(黄色・themeSoft)だけを使う前提で、文字は常に濃い色にする。
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
        .overlay(Capsule().stroke(Pop.border, lineWidth: 1))
    }
}

/// 見出しの横に置く丸いアイコン。カードの種類をひと目で分ける。
struct PopIconBadge: View {
    let systemImage: String
    let fill: Color
    let foreground: Color
    @ScaledMetric private var size: CGFloat

    init(systemImage: String, fill: Color = Pop.yellow, foreground: Color = Pop.inkOnAccent, size: CGFloat = 36) {
        self.systemImage = systemImage
        self.fill = fill
        self.foreground = foreground
        _size = ScaledMetric(wrappedValue: size, relativeTo: .title2)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(Pop.border, lineWidth: 1))
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
        shadow: Color = Pop.shadow,
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
            .contentShape(RoundedRectangle(cornerRadius: Pop.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 一覧の区切りの見出しと、その下に添える小さな説明。
struct PopSectionHeader: View {
    let title: String
    var marker: Color = Pop.yellow

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
