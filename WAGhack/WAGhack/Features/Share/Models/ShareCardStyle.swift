import SwiftUI

/// カードの中の箱(件数・話題・名前を載せる囲み)の見た目。
///
/// 1.8.0 (5)で足し、(7)(8)で「6つのレイアウト」「文字の色3種」に置き換えたが、(8)の写真を暗くするグラデーションが
/// 「アプリの画像感が強くなる」との声で、1.8.0 (9)でこの箱の3種に戻した。写真を隠さず、写真の明るさで白と黒を選び分けてもらう。
/// 最後に選んだものを覚えておく(`storageKey`)。値はUserDefaultsに残るので、`rawValue`は変えないこと。
nonisolated enum ShareCardBoxStyle: String, CaseIterable, Identifiable, Hashable {
    /// 白い箱にテーマ色の枠とずらした影。
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

    /// 最後に選んだ見た目を覚えておくキー(`@AppStorage`)。(5)(6)と同じキーにして、前に選んだ見た目を引き継ぐ。
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

    /// 箱の見た目に合わせた形の描き方。白の線は写真の上の白い線、黒の線は明るい写真の上の黒い線。
    var silhouetteStyle: SilhouetteMapView.Style {
        switch self {
        case .app: .solid
        case .whiteLine: .overPhoto
        case .blackLine: .overLightPhoto
        }
    }

    /// 「県の中の位置」「日本の中の位置」で、塗らない区画を薄く塗る色。
    var locationContext: Color {
        switch self {
        case .app: .gray
        case .whiteLine: .white
        case .blackLine: .black
        }
    }
}

/// 写真を敷いたカードのレイアウト(1.8.0 (10))。シェア画面の「レイアウト」で選び、最後に選んだものを覚えておく。
///
/// どちらも上に大きな形(ポリゴン)、その下に箱を置く。(9)の「プレビューのタップで箱を上・真ん中・下に動かす」は、
/// 「位置を変えるよりレイアウトを変えたい」との声でやめた(細かく動かしたいときは「位置を調整」、`ShareCardAdjustment`)。
/// 値はUserDefaultsに残るので`rawValue`は変えない。
nonisolated enum ShareCardBoxSize: String, CaseIterable, Identifiable, Hashable {
    /// (9)の箱を少し詰めたもの。載せる中身は(9)と同じ。
    case standard
    /// 箱をぐっと小さくして形を主役にする。中身は減らさず、並べ方と文字の大きさで詰める
    /// (制覇率の達成の札と「あと何市区町村で」だけは載せない、という声に合わせて省く)。
    case compact

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: "標準"
        case .compact: "小さい箱"
        }
    }

    static let storageKey = "shareCardBoxSize"
    static let defaultSize: ShareCardBoxSize = .standard
}

/// 形(ポリゴン)の見せ方(1.8.0 (8))。シェア画面の「形の見せ方」で選び、最後に選んだものを覚えておく。
///
/// 「その街が何県のどこか分かるように」との声から。この街のカードでは県全体の形を薄く描いてその街を塗り、
/// 都道府県・政令指定都市のカードでは日本全体を薄く描いてその県を塗る。全国のカードと「全国の都道府県」は
/// もともと日本地図なので選ばない(`ShareCardSelection.canShowLocation`)。値はUserDefaultsに残るので`rawValue`は変えない。
nonisolated enum ShareCardShapeMode: String, CaseIterable, Identifiable, Hashable {
    /// その範囲だけの形(制覇率のカードは行った所を塗った形)。
    case shapeOnly
    /// 一回り大きな範囲の中の位置。
    case location

    var id: Self { self }

    /// 選択肢の見出し。この街なら「県の中の位置」、都道府県・政令指定都市なら「日本の中の位置」。
    func title(isTown: Bool) -> String {
        switch self {
        case .shapeOnly: "形だけ"
        case .location: isTown ? "県の中の位置" : "日本の中の位置"
        }
    }

    static let storageKey = "shareCardShapeMode"
    static let defaultMode: ShareCardShapeMode = .location
}
