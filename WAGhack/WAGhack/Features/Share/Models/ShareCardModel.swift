import UIKit

/// 1枚のカードを描くのに要るものすべて。
///
/// シェア画面(`ShareCardSheet`)が選んだ状態から作り、`ShareCardCanvas`が描き、`ShareCardRenderer.render(_:)`が画像にする。
/// 1.8.0 (9)で見た目を(6)の「箱」のカードに戻した。カードの種類ごとの並び(地図と箱)は(6)のまま、写真があれば全面に敷き
/// (暗くしない)、箱を上・真ん中・下に置く。写真が無いときは(6)と同じ水玉の地に、本物の地図を薄く敷いた地図の枠を描く。
struct ShareCardModel {
    let subject: ShareCardSubject
    var size: ShareCardSize
    /// カードに敷く写真。
    var photo: UIImage? = nil
    /// 写真が無いときに地図の枠へ薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、図形だけの地図にする。
    var backdrop: ShareMapBackdrop? = nil
    var boxStyle: ShareCardBoxStyle = .defaultStyle
    /// 写真を敷いたときの箱の位置。写真が無いカードは並びが決まっているので使わない。
    var boxPosition: ShareCardBoxPosition = .bottom
    /// 「県の中の位置」「日本の中の位置」の形(`ShareCardSubjectFactory.locationShape`)。
    /// nilなら「形だけ」を選んだか、一回り大きな地図がまだ無い。
    var locationShape: ShareCardShape? = nil

    /// 実際に描く箱の見た目。白の線・黒の線は写真を隠さないための選択肢なので、写真が無いときはアプリの色で描く
    /// (水玉の地や薄い地図の上に白い字・線を載せると読めないため。(6)では写真が無くても線の版になっていた)。
    var effectiveBoxStyle: ShareCardBoxStyle { photo == nil ? .app : boxStyle }

    var summary: ShareCardSummary { subject.summary }
    /// ステッカーに描く形。
    var shape: ShareCardShape { locationShape ?? summary.shape }

    /// 箱の中の名前に添える小さな形。nilなら添えない。
    ///
    /// どのカードにも形が目に入る大きさで載るようにする(1.8.0 (8)の声)。地図の枠や写真の上の地図で形を大きく描くカードは、
    /// 「位置」を選んだときだけ一回り大きな範囲の中の位置を添える。写真を敷いた街のカード(初訪問・豆知識)は(6)では形が無かったので、
    /// 「形だけ」でもその街の形を添える。
    var boxShape: ShareCardShape? {
        if let locationShape { return locationShape }
        guard photo != nil else { return nil }
        switch subject {
        case .firstVisit, .trivia: return summary.shape
        case .japan, .region: return nil
        }
    }
}

/// カードの中身。ステッカーは、ここから作る要約(`ShareCardSummary`)で描く。
enum ShareCardSubject {
    /// 全国の地図。
    case japan(ShareCardContent, fill: ShareCardFill, maps: ShareCardMaps)
    /// 都道府県・政令指定都市・全国の都道府県の地図。地図を読み込めなかったときは`map`がnil。
    case region(RegionShareCardContent, map: SilhouetteMap?)
    /// 市区町村の初訪問。`highlightedCodes`は塗る区画(その街の全体)。
    case firstVisit(FirstVisitShareCardContent, map: SilhouetteMap?, highlightedCodes: Set<String>)
    /// 市区町村の豆知識(みどころ・都市伝説・この街でできること)。
    case trivia(TriviaShareCardContent, map: SilhouetteMap?, highlightedCodes: Set<String>)

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
