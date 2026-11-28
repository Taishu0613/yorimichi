import Foundation

/// カードの並び方。シェア画面の「レイアウト」で選ぶ(1.8.0 (7)で仕組みを用意)。
///
/// 中身の種類(`ShareCardSubjectKind`)ごとに、選べるレイアウトと初めのレイアウトを決める。
/// レイアウトを足すときは、ここに`case`を足し、`ShareCardSubjectKind.availableLayouts`に載せ、
/// `ShareCardCanvas`にそのレイアウトのViewを足す(`Layouts/`の下に1レイアウト1ファイル)。
/// 選べるものが1つだけの種類では、シェア画面に「レイアウト」の選択を出さない。
///
/// 値はUserDefaultsに残る(`ShareCardLayoutFamily.storageKey`)ので、`rawValue`は変えないこと。
nonisolated enum ShareCardLayout: String, CaseIterable, Identifiable, Hashable {
    /// これまでのカード(地図の枠＋数字の箱。写真を敷くと箱を上・真ん中・下に動かせる)。
    case standard

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: "標準"
        }
    }

    /// プレビューをタップして箱を上・真ん中・下に動かせるか。
    /// 標準は写真を敷いたときだけ(写真が無いカードは地図と箱の並びが決まっている)。
    func canMoveBox(hasPhoto: Bool) -> Bool {
        switch self {
        case .standard: hasPhoto
        }
    }
}

/// カードの中身の種類。種類ごとに選べるレイアウトと初めのレイアウトを持つ。
nonisolated enum ShareCardSubjectKind: Hashable {
    /// 全国・都道府県・政令指定都市の地図(都道府県の「全国の都道府県」も含む)。
    case map
    case firstVisit
    case trivia

    /// 選べるレイアウト。先頭から順に「レイアウト」の選択肢に並べる。
    var availableLayouts: [ShareCardLayout] {
        switch self {
        case .map, .firstVisit, .trivia: [.standard]
        }
    }

    /// 初めてシェアするときのレイアウト。
    var defaultLayout: ShareCardLayout { .standard }

    /// 最後に選んだレイアウトを覚えておく単位。
    var family: ShareCardLayoutFamily {
        switch self {
        case .map: .map
        case .firstVisit, .trivia: .town
        }
    }

    /// 覚えているレイアウトがこの種類で選べなければ、この種類の初めのレイアウトで描く。
    /// 覚えている値は書き換えない(選べる種類に戻ったら、また使う)。
    func resolvedLayout(_ stored: ShareCardLayout?) -> ShareCardLayout {
        guard let stored, availableLayouts.contains(stored) else { return defaultLayout }
        return stored
    }
}

/// 最後に選んだレイアウトを覚えておく単位。地図のカードと街のカードで別々に覚える。
nonisolated enum ShareCardLayoutFamily: String, Hashable {
    case map
    case town

    /// `@AppStorage`のキー。変えると前回の選択が読めなくなる。
    var storageKey: String { "shareCardLayout.\(rawValue)" }
}
