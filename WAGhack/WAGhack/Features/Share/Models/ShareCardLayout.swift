import Foundation

/// カードの並び方。シェア画面の「レイアウト」で選ぶ(1.8.0 (7))。
///
/// 1.8.0 (6)への声「背景の写真が主役になれるレイアウトを」「ポリゴン(塗った形)はアプリを使わないと真似しにくいので全般に活かしたい」
/// 「もうすこしシンプルなレイアウトでいい」を受けて、使いみちごとに1つずつ用意した。どれも中身を少なく(形・名前・数字1つ・小さなロゴ)し、
/// 余白を広く取り、飾りは足さない。これまでの「標準」は、この6つに置き換えた(バッジのカードはこれまでどおり)。
///
/// レイアウトを足すときは、ここに`case`を足し、`ShareCardSubjectKind.availableLayouts`に載せ、
/// `ShareCardCanvas`にそのレイアウトのView(`Layouts/`の下に1レイアウト1ファイル)を足す。
/// 値はUserDefaultsに残る(`ShareCardLayoutFamily.storageKey`)ので、`rawValue`は変えないこと。
nonisolated enum ShareCardLayout: String, CaseIterable, Identifiable, Hashable {
    /// 景色を見せる。写真を全面に敷き、細い帯に小さな形・名前・短い一言。
    case photo
    /// 景色を作品として見せる(フィード向け)。白い余白の中に写真を置き、下の余白に小さな形・名前・数字1つ。
    case photoMat
    /// 自分のカメラの写真に貼る(ストーリーズのスタンプ)。背景が透明なPNGに、形・名前・数字1つ。
    case sticker
    /// 制覇を自慢する。主役の数字を大きく、塗った形を中くらい、補足を1行。
    case number
    /// どこへ行ったかを見せる。塗った形をカードいっぱいに大きく、数字は小さく。
    case map
    /// みどころ・都市伝説を読んでもらう。本文を大きく、見出しに名前と小さな形。写真は上に細い帯で(任意)。
    case reading

    var id: Self { self }

    var title: String {
        switch self {
        case .photo: "フォト"
        case .photoMat: "フォト・余白"
        case .sticker: "ステッカー"
        case .number: "数字"
        case .map: "地図"
        case .reading: "読み物"
        }
    }

    /// 写真を敷けるか。ステッカーは透明にするので写真を使わない。
    var usesPhoto: Bool { self != .sticker }

    /// 写真が主役のレイアウトか。写真が無いときは選ぶよう案内し、写真の代わりに本物の地図を薄く敷く。
    var expectsPhoto: Bool { self == .photo || self == .photoMat }

    /// 箱(帯)の見た目(アプリの色・白の線・黒の線)を選べるか。箱の無いレイアウト(余白・数字・読み物)では出さない。
    var usesBoxStyle: Bool { self == .photo || self == .sticker || self == .map }

    /// プレビューをタップして帯を上・下に動かせるか。フォトだけ(ほかは並びが決まっている)。
    var canMoveBox: Bool { self == .photo }

    /// 縦長・正方形を選べるか。ステッカーは中身の大きさで書き出すので選ばない。
    var usesCardSize: Bool { self != .sticker }

    /// 背景が透明な画像にするか。透明な画像はJPEGにせず、PNGのファイルで共有する(`ShareCardActivity`)。
    var isTransparent: Bool { self == .sticker }
}

/// カードの中身の種類。種類ごとに選べるレイアウトと初めのレイアウトを持つ。バッジのカードはレイアウトを選ばない。
nonisolated enum ShareCardSubjectKind: Hashable, CaseIterable {
    /// 全国・都道府県・政令指定都市の地図(都道府県の「全国の都道府県」も含む)。
    case map
    case firstVisit
    /// みどころ・都市伝説・この街でできること。
    case trivia

    /// 選べるレイアウト。先頭が初めのレイアウト(★)で、この順に「レイアウト」の選択肢に並べる。
    var availableLayouts: [ShareCardLayout] {
        switch self {
        case .map: [.number, .map, .photo, .sticker]
        case .firstVisit: [.photo, .photoMat, .sticker]
        case .trivia: [.reading, .photo]
        }
    }

    /// 初めてシェアするときのレイアウト。
    var defaultLayout: ShareCardLayout { availableLayouts[0] }

    /// 最後に選んだレイアウトを覚えておく単位。
    var family: ShareCardLayoutFamily {
        switch self {
        case .map: .map
        case .firstVisit: .firstVisit
        case .trivia: .trivia
        }
    }

    /// 覚えているレイアウトがこの種類で選べなければ、この種類の初めのレイアウトで描く。
    /// 覚えている値は書き換えない(選べる種類に戻ったら、また使う)。
    func resolvedLayout(_ stored: ShareCardLayout?) -> ShareCardLayout {
        guard let stored, availableLayouts.contains(stored) else { return defaultLayout }
        return stored
    }
}

/// 最後に選んだレイアウトを覚えておく単位(カードの種類ごと)。
nonisolated enum ShareCardLayoutFamily: String, Hashable, CaseIterable {
    case map
    case firstVisit
    case trivia

    /// `@AppStorage`のキー。変えると前回の選択が読めなくなる。
    var storageKey: String { "shareCardLayout.\(rawValue)" }
}
