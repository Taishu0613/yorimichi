import UIKit

/// 1枚のカードを描くのに要るものすべて(1.8.0 (8))。
///
/// シェア画面(`ShareCardSheet`)が選んだ状態から作り、`ShareCardCanvas`が描き、`ShareCardRenderer.render(_:)`が画像にする。
/// どのカードも「全面の写真(無ければ薄い地図)＋まとまり1つ＋右の角のアプリ名」の同じ形で、
/// まとまりの大きさと中身はカードの種類(`ShareCardSubject.panelSize`)で決まる。
struct ShareCardModel {
    let subject: ShareCardSubject
    var size: ShareCardSize
    /// カードに敷く写真。
    var photo: UIImage? = nil
    /// 写真の代わりに薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、水玉の地にする。
    var backdrop: ShareMapBackdrop? = nil
    var textStyle: ShareCardTextStyle = .defaultStyle
    var panelPosition: ShareCardPanelPosition = .bottom
    /// 「県の中の位置」「日本の中の位置」の形(`ShareCardSubjectFactory.locationShape`)。
    /// nilなら、その範囲だけの形(`summary.shape`)で描く(「形だけ」を選んだとき・一回り大きな地図がまだ無いとき)。
    var locationShape: ShareCardShape? = nil

    var summary: ShareCardSummary { subject.summary }
    /// まとまりとステッカーに描く形。
    var shape: ShareCardShape { locationShape ?? summary.shape }
    var panelSize: ShareCardPanelSize { subject.panelSize }
    var logoCorner: ShareCardLogoCorner { panelSize.logoCorner(for: panelPosition) }
}

/// カードの中身。まとまりは、ここから作る要約(`ShareCardSummary`)で描く。
enum ShareCardSubject {
    /// 全国の地図。
    case japan(ShareCardContent, fill: ShareCardFill, maps: ShareCardMaps)
    /// 都道府県・政令指定都市・全国の都道府県の地図。地図を読み込めなかったときは`map`がnil。
    case region(RegionShareCardContent, map: SilhouetteMap?)
    /// 市区町村の初訪問。`highlightedCodes`は塗る区画(その街の全体)。
    case firstVisit(FirstVisitShareCardContent, map: SilhouetteMap?, highlightedCodes: Set<String>)
    /// 市区町村の豆知識(みどころ・都市伝説・この街でできること)。
    case trivia(TriviaShareCardContent, map: SilhouetteMap?, highlightedCodes: Set<String>)

    var panelSize: ShareCardPanelSize {
        switch self {
        case .japan, .region: .medium
        case .firstVisit: .small
        case .trivia: .large
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
}
