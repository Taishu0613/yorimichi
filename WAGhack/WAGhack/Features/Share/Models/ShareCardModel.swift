import UIKit

/// 1枚のカードを描くのに要るものすべて(1.8.0 (7))。
///
/// シェア画面(`ShareCardSheet`)が選んだ状態から作り、`ShareCardCanvas`がレイアウトに応じて描き、
/// `ShareCardRenderer.render(_:)`が画像にする。地図のカードも街のカードも同じ道を通すので、
/// 「どの中身を・どのレイアウトで・どの形で」の組み合わせを1か所(`ShareCardCanvas`)で決められる。
struct ShareCardModel {
    let subject: ShareCardSubject
    /// 描くレイアウト。シェア画面で、中身の種類で選べるもの(`ShareCardSubjectKind.resolvedLayout`)にしてから渡す。
    var layout: ShareCardLayout = .standard
    var size: ShareCardSize
    /// カードいっぱいに敷く写真。
    var photo: UIImage? = nil
    /// 地図の下に薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、図形だけで描く。
    var backdrop: ShareMapBackdrop? = nil
    var boxStyle: ShareCardBoxStyle = .app
    /// 写真の上の箱の位置(`ShareCardLayout.canMoveBox`のときだけ使う)。
    var boxPosition: ShareCardBoxPosition = .bottom
}

/// カードの中身。標準のレイアウトでは、中身ごとに専用のカード(`Layouts/Standard`)で描く。
enum ShareCardSubject {
    /// 全国の地図。
    case japan(ShareCardContent, fill: ShareCardFill, maps: ShareCardMaps)
    /// 都道府県・政令指定都市・全国の都道府県の地図。地図を読み込めなかったときは`map`がnil。
    case region(RegionShareCardContent, map: SilhouetteMap?)
    /// 市区町村の初訪問。`highlightedCodes`は塗る区画(その街の全体)。
    case firstVisit(FirstVisitShareCardContent, map: SilhouetteMap?, highlightedCodes: Set<String>)
    /// 市区町村の豆知識(みどころ・都市伝説・この街でできること)。
    case trivia(TriviaShareCardContent, map: SilhouetteMap?, highlightedCodes: Set<String>)

    var kind: ShareCardSubjectKind {
        switch self {
        case .japan, .region: .map
        case .firstVisit: .firstVisit
        case .trivia: .trivia
        }
    }

    /// 画像と一緒に共有する文。
    var shareText: String {
        switch self {
        case .japan(let content, _, _): content.shareText
        case .region(let content, _): content.shareText
        case .firstVisit(let content, _, _): content.shareText
        case .trivia(let content, _, _): content.shareText
        }
    }

    /// 共有シートの上に出す見出し。
    var shareTitle: String {
        switch self {
        case .japan: "わたしの日本地図"
        case .region(let content, _): content.headline
        case .firstVisit(let content, _, _): "\(content.municipalityName) 初訪問"
        case .trivia(let content, _, _): "\(content.municipalityName)の\(content.title)"
        }
    }

    /// 地図。本物の地図を撮る範囲を決めるのに使う。
    var map: SilhouetteMap? {
        switch self {
        case .japan(_, let fill, let maps): fill == .municipalities ? maps.municipalityMap : maps.prefectureMap
        case .region(_, let map): map
        case .firstVisit(_, let map, _): map
        case .trivia(_, let map, _): map
        }
    }
}

/// 共有するカード。画像と、一緒に共有する文・共有シートの見出し。
struct RenderedShareCard {
    let image: UIImage
    let message: String
    let title: String
}
