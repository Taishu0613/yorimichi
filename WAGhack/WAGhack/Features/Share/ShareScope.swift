import Foundation

/// シェアするカードの範囲。全国・1つの都道府県・1つの政令指定都市のどれか。
///
/// 全国の地図だけでは進み具合が見えにくく、日本全体を塗り終えるまでシェアする機会が無いという声を受けて、
/// 都道府県・政令指定都市の単位でも制覇率を見せられるようにした(1.8.0 (2))。
nonisolated enum ShareScope: Hashable, Identifiable {
    case japan
    /// 都道府県コード(2桁)。
    case prefecture(code: String)
    /// 政令指定都市そのもの(例: 名古屋市 23100)の行政区域コード。
    case designatedCity(code: String)

    var id: Self { self }

    var kind: ShareScopeKind {
        switch self {
        case .japan: .japan
        case .prefecture: .prefecture
        case .designatedCity: .designatedCity
        }
    }
}

/// シェア画面の「範囲」の選択肢。都道府県・政令指定都市は、さらにどれをシェアするかを選ぶ。
nonisolated enum ShareScopeKind: String, CaseIterable, Identifiable, Hashable {
    case japan
    case prefecture
    case designatedCity

    var id: Self { self }

    var title: String {
        switch self {
        case .japan: "全国"
        case .prefecture: "都道府県"
        case .designatedCity: "政令指定都市"
        }
    }
}

/// シェア画面で選べる都道府県・政令指定都市。訪れたものだけを、制覇率の高い順に並べる。
///
/// 制覇率が同じなら行政区域コードの順(北から南)にして、開くたびに並びが変わらないようにする。
struct ShareScopeCandidates {
    let prefectures: [PrefectureExploration]
    let designatedCities: [DesignatedCityExploration]

    /// - Parameter scope: 開いた画面の範囲。訪問済みでなくても選べるよう、一覧に必ず入れる
    ///   (都道府県単独の記録だけの県など、開いた画面と選択肢がずれないようにするため)。
    init(summary: ExplorationSummary, including scope: ShareScope? = nil) {
        prefectures = summary.prefectures
            .filter { $0.isVisited || scope == .prefecture(code: $0.code) }
            .sorted { Self.isOrderedBefore($0.progress, $0.code, $1.progress, $1.code) }
        designatedCities = summary.designatedCities
            .filter { $0.isVisited || scope == .designatedCity(code: $0.code) }
            .sorted { Self.isOrderedBefore($0.progress, $0.code, $1.progress, $1.code) }
    }

    /// 選べる範囲の種類。全国はいつでも選べ、都道府県・政令指定都市は候補が1つ以上あるときだけ出す。
    var availableKinds: [ShareScopeKind] {
        var kinds: [ShareScopeKind] = [.japan]
        if !prefectures.isEmpty { kinds.append(.prefecture) }
        if !designatedCities.isEmpty { kinds.append(.designatedCity) }
        return kinds
    }

    private static func isOrderedBefore(_ lhs: ExplorationCount, _ lhsCode: String, _ rhs: ExplorationCount, _ rhsCode: String) -> Bool {
        if lhs.fraction != rhs.fraction { return lhs.fraction > rhs.fraction }
        return lhsCode < rhsCode
    }
}
