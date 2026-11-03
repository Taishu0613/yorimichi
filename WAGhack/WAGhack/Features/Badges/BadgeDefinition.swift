import SwiftUI

/// バッジの識別子。生の値は保存する獲得記録(`BadgeAchievement`)と画像の名前(`badge_<id>`)に使うので変えないこと。
/// 並び順はコレクション帳での表示順(固定)。
nonisolated enum BadgeID: String, CaseIterable, Codable, Hashable {
    case firstStep = "first_step"
    case footprintCollector = "footprint_collector"
    case prefectureTraveler = "prefecture_traveler"
    case localExplorer = "local_explorer"
    case helloMetropolis = "hello_metropolis"
    case tokyo23 = "tokyo_23"
    case twinTowns = "twin_towns"
    case numberTraveler = "number_traveler"
    case tripleBoundary = "triple_boundary"
    case threeCapitals = "three_capitals"
}

/// 何を数えて判定するか。判定そのものは`BadgeRuleEvaluator`が行い、画面は判定を個別に実装しない。
enum BadgeCriterion {
    /// 踏破率に含まれる市区町村の訪問数(政令指定都市は区で数え、市そのものは数えない)。
    case visitedMunicipalityCount
    /// 訪れた都道府県の数。都道府県だけの記録(`VisitedPrefecture`)も含め、旅の記録の「訪れた都道府県」と同じ数にする。
    case visitedPrefectureCount
    /// 1つの都道府県で訪れた市区町村の数のうち、最も多いもの。
    case municipalitiesInOnePrefecture
    /// 対象の市区町村(行政区域コード)のうち訪れた数。
    case visitedTargets(codes: [String])
    /// 地域ごとに1つ以上訪れた地域の数(三都物語: 東京23区・京都市・大阪市)。
    case visitedAreas([BadgeArea])
    /// 同じ名前の市区町村の組のうち、ちがう都道府県で2つ以上訪れた組の数(ふたごのまち)。
    case sameNameGroups([[String]])
    /// 集めた数字の種類の数(数字の旅人)。数字ごとに、名前にその数字が入っている市区町村を1つ訪れれば集まる。
    case numeralCollection([BadgeNumeral])
    /// 名前の付いた目的地のうち訪れた数(都会にこんにちは: 池袋・新宿・渋谷)。目的地は区などの市区町村で判定する。
    case themeSpots([BadgeThemeSpot])
    /// 記録した場所がおたがい`maxDistanceMeters`以内にある市区町村の数のうち、最も多いもの(超・境目！)。
    /// 判定には記録した場所の座標を使う。
    case nearbyMunicipalities(maxDistanceMeters: Double)
    /// 判定がまだ無い。一覧には絵柄と名前だけを見せ、獲得済みにはしない。
    case comingSoon
}

/// 段階式バッジのランク。名前は全バッジで共通にし、色だけでなく星の数と文字でも区別する。
enum BadgeRank: Int, CaseIterable {
    case bronze, silver, gold, platinum

    var name: String {
        switch self {
        case .bronze: "ブロンズ"
        case .silver: "シルバー"
        case .gold: "ゴールド"
        case .platinum: "プラチナ"
        }
    }

    /// スタンプの外周の色。
    var ringColor: Color {
        switch self {
        case .bronze: Color(red: 0.80, green: 0.52, blue: 0.30)
        case .silver: Color(red: 0.66, green: 0.70, blue: 0.75)
        case .gold: Color(red: 0.95, green: 0.74, blue: 0.20)
        case .platinum: Color(red: 0.55, green: 0.80, blue: 0.86)
        }
    }

    /// 獲得したランクの数(1始まり)から求める。0以下なら未獲得なのでnil。
    init?(earnedTierCount: Int) {
        self.init(rawValue: earnedTierCount - 1)
    }
}

/// 判定や地図の導線に使う地域。中心と範囲は、詳細の「地図で探す」で地域全体を見せるためのもの。
struct BadgeArea {
    let name: String
    let codes: [String]
    let latitude: Double
    let longitude: Double
    /// 地域全体が収まる表示範囲(縦横のメートル)。
    let spanMeters: Double
}

/// 数字の旅人で集める数字1種類と、名前にその数字が入っている市区町村。
struct BadgeNumeral {
    let symbol: String
    let codes: [String]
}

/// テーマで巡る目的地。街の呼び名(池袋)と、判定に使う市区町村(豊島区)は一致しないことがあるので両方持ち、
/// 画面では両方を見せて「どこを記録すればよいか」と判定を一致させる。
struct BadgeThemeSpot {
    let label: String
    let code: String
}

/// バッジの詳細から地図へ向かう先。地図を動かすのは持ち主の`MapScreen`なので、ここでは行き先だけを表す。
enum BadgeMapFocus {
    /// 地域全体(東京23区・京都市など)。
    case area(BadgeArea)
    /// 都道府県全体。
    case prefecture(code: String)
    /// 市区町村1つ。
    case municipality(code: String, prefectureCode: String)
}

/// スタンプの仮の絵柄。専用の画像(`BadgeDefinition.assetName`)がアセットに入れば、そちらが優先される。
/// 主役の絵柄に小さな添え物を重ね、要件のモチーフ(足跡＋道標など)に近づけている。
struct BadgeArtwork {
    let symbolName: String
    /// 主役の右下に小さく添える絵柄。
    var secondarySymbolName: String? = nil
    /// 印影の地の色。
    let primary: Color
    /// 内側の飾りと、ランクの無いバッジの外周の色。
    let accent: Color
}

/// バッジ1種類の定義。閾値・対象地域は製品として確定していないため、ここ(と`BadgeCatalog`)のデータだけを変えれば
/// 判定・画面の両方に反映されるようにしている。
struct BadgeDefinition: Identifiable {
    let id: BadgeID
    let name: String
    /// 一覧の下や詳細の名前の下に添える、旅の目的を感じる短い一文。
    let summary: String
    let category: String
    let criterion: BadgeCriterion
    /// 段階ごとの閾値(昇順)。段階の無いバッジは1つだけ持つ。
    let tiers: [Int]
    /// 進捗の数の単位(「市区町村」「区」など)。
    let unit: String
    let artwork: BadgeArtwork
    /// 閾値から達成条件の文を作る。詳細画面の「達成条件」に出す。
    let conditionText: (Int) -> String
    /// 詳細の「地図で探す」で見せる地域。対象が1つの地域にまとまっているバッジだけが持つ。
    var mapArea: BadgeArea? = nil
    /// 詳細の「旅のヒント」。対象の街の面白さや探し方を短く伝える。
    var hint: String? = nil

    /// 差し替え用の画像の名前。`badge_first_step`のように安定した名前にしておき、後から画像を追加するだけで入れ替わる。
    var assetName: String { "badge_\(id.rawValue)" }

    var isTiered: Bool { tiers.count > 1 }

    var isAvailable: Bool {
        if case .comingSoon = criterion { return false }
        return true
    }
}
