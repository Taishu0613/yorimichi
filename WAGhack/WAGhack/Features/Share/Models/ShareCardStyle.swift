import SwiftUI

/// カードの文字の色(1.8.0 (8))。シェア画面の「文字の色」で選び、最後に選んだものを覚えておく(`storageKey`)。
///
/// 1.8.0 (7)の6つのレイアウトと箱の見た目3種は「複雑」との声で無くし、写真を全面に敷いた上に「まとまり」
/// (`ShareCardPanel`)を1つだけ置く形にした。見た目の違いは文字の色だけにし、箱の枠線は引かない。
/// 値はUserDefaultsに残るので、`rawValue`は変えないこと。
nonisolated enum ShareCardTextStyle: String, CaseIterable, Identifiable, Hashable {
    /// 白い文字。写真を、まとまりの側からグラデーションで少し暗くして読めるようにする(初めの見た目)。
    case light
    /// 黒い文字。写真全体を白で薄めて読めるようにする。
    case dark
    /// アプリの色。まとまりを白い下地に載せ、数字や見出しをテーマ色にする。
    case theme

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "白い文字"
        case .dark: "黒い文字"
        case .theme: "アプリの色"
        }
    }

    static let storageKey = "shareCardTextStyle"
    static let defaultStyle: ShareCardTextStyle = .light
}

/// まとまりの位置。プレビューをタップするたびに上と下を入れ替える。中身と大きさは変わらない。
/// シェア画面を開いている間だけ持つ(覚えておかない)。
nonisolated enum ShareCardPanelPosition: String, CaseIterable, Hashable {
    case top
    case bottom

    var next: ShareCardPanelPosition {
        switch self {
        case .top: .bottom
        case .bottom: .top
        }
    }
}

/// まとまりの大きさ。カードの種類で決まり、選ばない。
nonisolated enum ShareCardPanelSize: Hashable {
    /// 初訪問。左下(上)に、形・名前・初めて訪れた日。
    case small
    /// 制覇率(全国・都道府県・政令指定都市)。横幅いっぱいに、名前・大きな数字・n/N・塗った形。
    case medium
    /// みどころ・都市伝説・この街でできること。横幅いっぱいに、見出し・形と名前・本文。写真の上半分は空ける。
    case large

    /// アプリ名を置く角。小さなまとまりは左に寄せるので同じ側の右の角、横幅いっぱいのまとまりは反対側の右の角。
    func logoCorner(for position: ShareCardPanelPosition) -> ShareCardLogoCorner {
        switch self {
        case .small: position == .top ? .topTrailing : .bottomTrailing
        case .medium, .large: position == .top ? .bottomTrailing : .topTrailing
        }
    }
}

/// アプリ名「よりみち」を置く角。どのカードでも右上か右下。
nonisolated enum ShareCardLogoCorner: Hashable {
    case topTrailing
    case bottomTrailing
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
