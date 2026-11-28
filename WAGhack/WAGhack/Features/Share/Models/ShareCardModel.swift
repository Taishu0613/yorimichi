import UIKit

/// 1枚のカードを描くのに要るものすべて(1.8.0 (7))。
///
/// シェア画面(`ShareCardSheet`)が選んだ状態から作り、`ShareCardCanvas`がレイアウトに応じて描き、
/// `ShareCardRenderer.render(_:)`が画像にする。地図のカードも街のカードも同じ道を通すので、
/// 「どの中身を・どのレイアウトで・どの形で」の組み合わせを1か所(`ShareCardCanvas`)で決められる。
struct ShareCardModel {
    let subject: ShareCardSubject
    /// 描くレイアウト。シェア画面で、中身の種類で選べるもの(`ShareCardSubjectKind.resolvedLayout`)にしてから渡す。
    var layout: ShareCardLayout
    /// 縦長・正方形。ステッカーでは使わない(中身の大きさで書き出す)。
    var size: ShareCardSize
    /// カードに敷く写真。
    var photo: UIImage? = nil
    /// 写真の代わりに薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、水玉の地にする。
    var backdrop: ShareMapBackdrop? = nil
    var boxStyle: ShareCardBoxStyle = .app
    /// フォトの帯の位置。
    var boxPosition: ShareCardBoxPosition = .bottom

    var summary: ShareCardSummary { subject.summary }
}

/// カードの中身。どのレイアウトも、ここから作る要約(`ShareCardSummary`)で描く。
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
}

/// 共有するカード。画像と、一緒に共有する文・共有シートの見出し。
struct RenderedShareCard {
    let image: UIImage
    let message: String
    let title: String
    /// 背景が透明な画像(ステッカー)か。透明な画像はPNGのファイルとして共有する(写真に保存しても透明のまま残すため)。
    var isTransparent = false
}
