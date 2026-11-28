import SwiftUI

/// カードの中の箱(件数・話題・名前を載せる囲み)の見た目。
///
/// 1.8.0 (4)への声「アプリのテーマとは別に、白の線で背景を透明にした版や、その黒版も欲しい」を受けて足した(1.8.0 (5))。
/// 写真を敷いたときに写真を隠さないための選択肢で、写真の明るさで白と黒を選び分けてもらう。
/// 最後に選んだものを覚えておく(`storageKey`)。値はUserDefaultsに残るので、`rawValue`は変えないこと。
nonisolated enum ShareCardBoxStyle: String, CaseIterable, Identifiable, Hashable {
    /// これまでどおり、白い箱にテーマ色の枠とずらした影。
    case app
    /// 背景は透明で、白の枠と白の文字。どんな写真でも読めるよう、薄い影を落とす。
    case whiteLine
    /// 背景は透明で、黒の枠と黒の文字。明るい写真向け。
    case blackLine

    var id: Self { self }

    var title: String {
        switch self {
        case .app: "アプリの色"
        case .whiteLine: "白の線"
        case .blackLine: "黒の線"
        }
    }

    /// 最後に選んだ見た目を覚えておくキー(`@AppStorage`)。
    static let storageKey = "shareCardBoxStyle"
    /// 初めてシェアするときの見た目。
    static let defaultStyle: ShareCardBoxStyle = .app

    /// 箱の中の主な文字の色。`app`のときは呼び出し側の色(ふだんは`Pop.ink`)。
    func primary(_ appColor: Color = Pop.ink) -> Color {
        switch self {
        case .app: appColor
        case .whiteLine: .white
        case .blackLine: .black
        }
    }

    /// 箱の中の小さな見出し・単位の色。
    func secondary(_ appColor: Color = Pop.muted) -> Color {
        switch self {
        case .app: appColor
        case .whiteLine: .white.opacity(0.85)
        case .blackLine: .black.opacity(0.7)
        }
    }

    /// 見出しの蛍光ペン。線の版は箱を透明にするので、塗りの帯も引かない(白い字に黄色の帯は読めないため)。
    func marker(_ appColor: Color = Pop.yellow) -> Color {
        self == .app ? appColor : .clear
    }

    /// 踏破率のバーの塗りと地。
    var progressFill: Color { primary(Pop.theme) }
    var progressTrack: Color {
        switch self {
        case .app: Pop.themeTint.opacity(0.8)
        case .whiteLine: .white.opacity(0.3)
        case .blackLine: .black.opacity(0.15)
        }
    }
}

/// 写真(や地図)の上に置いた箱の位置。プレビューをタップするたびに上→真ん中→下→上と変える。
///
/// シェア画面を開いている間だけ持ち、種類や範囲を切り替えても同じ位置にする(覚えておくのは見た目だけ)。
nonisolated enum ShareCardBoxPosition: String, CaseIterable, Hashable {
    case top
    case middle
    case bottom

    /// タップしたときの次の位置。
    var next: ShareCardBoxPosition {
        switch self {
        case .top: .middle
        case .middle: .bottom
        case .bottom: .top
        }
    }

    var title: String {
        switch self {
        case .top: "上"
        case .middle: "真ん中"
        case .bottom: "下"
        }
    }
}

extension View {
    /// カードの中の箱。`app`は`popCard`(白い箱・テーマ色の枠・ずらした影)、線の版は背景を透明にして枠だけを引く。
    ///
    /// 白の線は明るい写真の上でも字と枠が読めるよう、中身ごと薄い影を落とす(`compositingGroup`で箱全体を1枚にしてから)。
    @ViewBuilder
    func shareCardBox(
        _ style: ShareCardBoxStyle,
        fill: Color = Pop.card,
        shadow: Color = Pop.shadow,
        cornerRadius: CGFloat = Pop.cornerRadius,
        shadowOffset: CGFloat = 4
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch style {
        case .app:
            popCard(fill: fill, shadow: shadow, cornerRadius: cornerRadius, shadowOffset: shadowOffset)
        case .whiteLine:
            overlay(shape.stroke(Color.white, lineWidth: 2))
                .compositingGroup()
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1)
        case .blackLine:
            overlay(shape.stroke(Color.black, lineWidth: 2))
        }
    }
}

/// 写真を敷いたカードで、箱を上・真ん中・下に置く。
///
/// - 上・下: 箱と`filler`(地図のカードなら地図、ほかは空き)を縦に並べ、箱の無い側を`filler`に譲る。
///   地図のカードで箱が地図に重ならないようにするため。
/// - 真ん中: `filler`を全体に広げ、その上の真ん中に箱を置く。
struct ShareCardBoxArrangement<Box: View, Filler: View>: View {
    let position: ShareCardBoxPosition
    var spacing: CGFloat = 12
    @ViewBuilder let box: () -> Box
    @ViewBuilder let filler: () -> Filler

    var body: some View {
        switch position {
        case .top:
            VStack(spacing: spacing) {
                box()
                filler().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .middle:
            ZStack {
                filler().frame(maxWidth: .infinity, maxHeight: .infinity)
                box()
            }
        case .bottom:
            VStack(spacing: spacing) {
                filler().frame(maxWidth: .infinity, maxHeight: .infinity)
                box()
            }
        }
    }
}

/// 写真の上に描く地図。与えられた広さいっぱいに、縦横比を保って区画を塗る(本物の地図は敷かない)。
struct ShareCardPhotoMap: View {
    let map: SilhouetteMap?
    let visitedCodes: Set<String>
    var outlineWidth: CGFloat = 0.6
    var placeholderSystemImage = "map.fill"

    var body: some View {
        GeometryReader { proxy in
            ShareMapCanvas(
                map: map, visitedCodes: visitedCodes,
                box: ShareCardMapBox(width: proxy.size.width, height: proxy.size.height, padding: 0, bottomPadding: 0),
                backdrop: nil, outlineWidth: outlineWidth, placeholderSystemImage: placeholderSystemImage,
                cornerRadius: 0, isOverPhoto: true
            )
        }
    }
}
