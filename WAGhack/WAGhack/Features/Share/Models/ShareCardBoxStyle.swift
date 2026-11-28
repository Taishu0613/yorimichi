import SwiftUI

/// カードの中の箱(件数・話題・名前を載せる囲み)の見た目。
///
/// 1.8.0 (4)への声「アプリのテーマとは別に、白の線で背景を透明にした版や、その黒版も欲しい」を受けて足した(1.8.0 (5))。
/// 写真を敷いたときに写真を隠さないための選択肢で、写真の明るさで白と黒を選び分けてもらう。
/// 最後に選んだものを覚えておく(`storageKey`)。値はUserDefaultsに残るので、`rawValue`は変えないこと。
enum ShareCardBoxStyle: String, CaseIterable, Identifiable, Hashable {
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
