import Foundation

/// 市区町村のシェア画面で切り替えるカードの種類。並び順は画面の切り替えの並び。
enum MunicipalityShareKind: String, CaseIterable, Identifiable, Hashable {
    case firstVisit
    case highlights
    case legend
    case spots

    var id: Self { self }

    /// 切り替えの見出し。4つを横に並べても切れないよう短くする(「この街でできること」は「できること」)。
    var title: String {
        switch self {
        case .firstVisit: "初訪問"
        case .highlights: "みどころ"
        case .legend: "都市伝説"
        case .spots: "できること"
        }
    }
}

/// 市区町村のシェア画面に渡す、その街のカードの材料。
///
/// 図鑑・初訪問のお祝いのどこから開いても同じ形で渡し、同じ画面(`ShareCardSheet`の`.town`)を開く。
/// SwiftDataのモデル(`Municipality`)をそのまま持たず値で持つのは、出せるカードの判定をテストしやすくするため。
struct MunicipalityShareSubject: Hashable {
    let target: ShareMunicipalityTarget
    let isVisited: Bool
    /// みどころ(マスタの「豆知識(有名なもの)」)。
    let highlightsText: String
    /// 怪奇・都市伝説(マスタの「豆知識(歴史)」)。
    let legendText: String
    /// この街でできること(みどころのマスタの順)。
    let spots: [YorimichiSpot]
    /// 初めて訪れた日。確かな日が分かるとき(初訪問を記録した直後)だけ渡す(`FirstVisitShareCardContent.firstVisitDate`)。
    let firstVisitDate: Date?

    init(
        target: ShareMunicipalityTarget, isVisited: Bool, highlightsText: String, legendText: String, spots: [YorimichiSpot],
        firstVisitDate: Date? = nil
    ) {
        self.target = target
        self.isVisited = isVisited
        self.highlightsText = highlightsText
        self.legendText = legendText
        self.spots = spots
        self.firstVisitDate = firstVisitDate
    }

    /// マスタの市区町村から作る。スポットは図鑑と同じく、マスタのJSONから読む。
    init(target: ShareMunicipalityTarget, isVisited: Bool, municipality: Municipality, firstVisitDate: Date? = nil) {
        self.init(
            target: target,
            isVisited: isVisited,
            highlightsText: municipality.famousThingsTrivia,
            legendText: municipality.historyTrivia,
            spots: YorimichiSpot.spots(fromJSON: municipality.spotsJSON),
            firstVisitDate: firstVisitDate
        )
    }

    /// この街で出せるカードの種類。
    var availableKinds: [MunicipalityShareKind] {
        Self.availableKinds(isVisited: isVisited, highlightsText: highlightsText, legendText: legendText, hasSpots: !spots.isEmpty)
    }

    /// 出せるカードが1つでもあるか。無ければ入口のボタンを出さない。
    var canShare: Bool { !availableKinds.isEmpty }

    /// 出せるカードの種類。
    /// - 初訪問: 訪れた街だけ(まだ行っていない街の「初訪問」は事実と違うため)
    /// - みどころ: 空欄でなければ
    /// - 都市伝説: 空欄と「特に有名な怪談・都市伝説はありません」の決まり文句でなければ
    /// - この街でできること: スポットが1件以上あれば
    static func availableKinds(isVisited: Bool, highlightsText: String, legendText: String, hasSpots: Bool) -> [MunicipalityShareKind] {
        var kinds: [MunicipalityShareKind] = []
        if isVisited { kinds.append(.firstVisit) }
        if TriviaShareCardContent.isShareableHighlights(highlightsText) { kinds.append(.highlights) }
        if TriviaShareCardContent.isShareableLegend(legendText) { kinds.append(.legend) }
        if hasSpots { kinds.append(.spots) }
        return kinds
    }

    /// 開いたときに選んでおく種類。押した入口の種類が出せなければ、出せる最初の種類にする。
    func initialKind(preferred: MunicipalityShareKind?) -> MunicipalityShareKind? {
        let kinds = availableKinds
        if let preferred, kinds.contains(preferred) { return preferred }
        return kinds.first
    }

    /// 豆知識のカードの話題。初訪問は豆知識のカードではないのでnil。
    func topic(for kind: MunicipalityShareKind, spotIndex: Int) -> TriviaShareCardContent.Topic? {
        switch kind {
        case .firstVisit:
            return nil
        case .highlights:
            return .highlights(highlightsText)
        case .legend:
            return .legend(legendText)
        case .spots:
            guard spots.indices.contains(spotIndex) else { return nil }
            return TriviaShareCardContent.spotTopic(spots[spotIndex])
        }
    }
}

/// 市区町村のシェア画面の上の切り替え(「この街 / 愛知県 / 全国」)の1つ。
struct TownShareScopeOption: Hashable, Identifiable {
    let target: ShareCardTarget
    let title: String

    var id: ShareCardTarget { target }

    /// この街から切り替えられる範囲。1段だけ上(その街の都道府県)と全国にする(1.8.0 (5))。
    ///
    /// 都道府県は行政区域コードの頭2桁で探す。集計に無い(マスタに無いコードの)ときは都道府県を出さず、この街と全国だけにする。
    /// 政令指定都市の地図はこれまでどおり政令指定都市の画面のメニューから開く(切り替えを2段にしないため)。
    static func options(townCode: String, prefectures: [PrefectureExploration]) -> [TownShareScopeOption] {
        var options = [TownShareScopeOption(target: .town, title: "この街")]
        let prefectureCode = String(townCode.prefix(2))
        if townCode.count == 5, let prefecture = prefectures.first(where: { $0.code == prefectureCode }) {
            options.append(TownShareScopeOption(target: .region(.prefecture(code: prefecture.code)), title: prefecture.name))
        }
        options.append(TownShareScopeOption(target: .region(.japan), title: "全国"))
        return options
    }
}

/// シェア画面で今描いているカード。市区町村のカードか、全国・都道府県・政令指定都市の地図のカード。
enum ShareCardTarget: Hashable {
    case town
    case region(ShareScope)
}
