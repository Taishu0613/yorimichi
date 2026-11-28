import SwiftUI

/// カード1枚を描く。どのカードもここを通る(`ShareCardRenderer.render(_:)`)。
///
/// 1.8.0 (9)で、見た目を(6)の「箱」のカードに戻した。
/// - 写真があれば全面に敷く。写真は暗くしない(グラデーションは「アプリの画像感が強くなる」との声でやめた)。
/// - 写真の上は、上に大きな形(ポリゴン)、その下に箱(`ShareCardPhotoComposition`)。箱の大きさは2つのレイアウト
///   (`ShareCardBoxSize`)から選び、「位置を調整」で箱と形をずらせる(`ShareCardAdjustment`、1.8.0 (10))。
/// - 箱の見た目は3種(`ShareCardBoxStyle`)。
/// - アプリ名「よりみち」はカードの右下の角に小さく置き、箱と重なるときだけ右上の角にする(1.8.0 (10)。`ShareCardLogoCorner`)。
struct ShareCardCanvas: View {
    let model: ShareCardModel

    var body: some View {
        content
            .overlayPreferenceValue(ShareCardBoxBoundsKey.self) { boxAnchor in
                GeometryReader { proxy in
                    let corner = ShareCardLogoCorner.corner(
                        avoiding: boxAnchor.map { proxy[$0] },
                        bottomLogoFrame: ShareCardAppMark.cornerFrame(.bottomTrailing, size: model.size)
                    )
                    ShareCardAppMark(logoSize: ShareCardAppMark.logoSize(for: model.size), isOverPhoto: model.photo != nil)
                        .fixedSize()
                        .padding(ShareCardAppMark.margin(for: model.size))
                        .frame(
                            width: proxy.size.width, height: proxy.size.height,
                            alignment: corner == .topTrailing ? .topTrailing : .bottomTrailing
                        )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.subject {
        case .japan(let content, let fill, let maps):
            JapanShareCardView(content: content, fill: fill, maps: maps, model: model)
        case .region(let content, let map):
            RegionShareCardView(content: content, map: map, model: model)
        case .firstVisit(let content, let map, let highlightedCodes):
            FirstVisitShareCardView(content: content, map: map, highlightedCodes: highlightedCodes, model: model)
        case .trivia(let content, let map, let highlightedCodes):
            TriviaShareCardView(content: content, map: map, highlightedCodes: highlightedCodes, model: model)
        }
    }
}

extension ShareCardSubject {
    /// 写真が無いときに本物の地図を敷く、地図の枠の種類。
    var mapBoxKind: ShareCardMapBoxKind {
        switch self {
        case .japan: .japan
        case .region: .region
        case .firstVisit: .firstVisit
        case .trivia: .trivia
        }
    }
}
