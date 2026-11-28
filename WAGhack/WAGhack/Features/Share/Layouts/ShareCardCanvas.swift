import SwiftUI

/// カード1枚を描く。どのカードもここを通る(`ShareCardRenderer.render(_:)`)。
///
/// 1.8.0 (9)で、見た目を(6)の「箱」のカードに戻した。カードの種類ごとに(6)の並びで描く。
/// - 写真があれば全面に敷く。写真は暗くしない(グラデーションは「アプリの画像感が強くなる」との声でやめた)。
/// - 箱の見た目は3種(`ShareCardBoxStyle`)、写真の上の箱は上・真ん中・下(`ShareCardBoxPosition`)。
/// - アプリ名「よりみち」は箱の下の行の右に置き、箱と重ねない(`ShareCardAppMark`)。
struct ShareCardCanvas: View {
    let model: ShareCardModel

    var body: some View {
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
