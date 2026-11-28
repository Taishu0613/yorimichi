import SwiftUI

/// カード1枚を、選んだレイアウトで描く(1.8.0 (7))。どのカードもここを通る(`ShareCardRenderer.render(_:)`)。
///
/// レイアウトを足すときは、ここの`switch`にそのレイアウトのViewを足す。
/// 1つのレイアウトが中身の種類ごとに描き分けを要るときは、`standard`のように中身で分ける。
struct ShareCardCanvas: View {
    let model: ShareCardModel

    var body: some View {
        switch model.layout {
        case .standard:
            StandardCardLayout(model: model)
        }
    }
}

/// 標準のレイアウト。中身ごとに、これまでの専用のカード(`Layouts/Standard`)で描く。
struct StandardCardLayout: View {
    let model: ShareCardModel

    var body: some View {
        switch model.subject {
        case .japan(let content, let fill, let maps):
            JapanStandardCard(
                content: content, size: model.size, fill: fill, maps: maps, backdrop: model.backdrop,
                photo: model.photo, boxStyle: model.boxStyle, boxPosition: model.boxPosition
            )
        case .region(let content, let map):
            RegionStandardCard(
                content: content, size: model.size, map: map, backdrop: model.backdrop,
                photo: model.photo, boxStyle: model.boxStyle, boxPosition: model.boxPosition
            )
        case .firstVisit(let content, let map, let highlightedCodes):
            // 写真があるときは地図を描かない(写真の上に記録の箱だけを載せる)。
            FirstVisitStandardCard(
                content: content, size: model.size, photo: model.photo, map: model.photo == nil ? map : nil,
                highlightedCodes: highlightedCodes, backdrop: model.backdrop,
                boxStyle: model.boxStyle, boxPosition: model.boxPosition
            )
        case .trivia(let content, let map, let highlightedCodes):
            TriviaStandardCard(
                content: content, size: model.size, map: model.photo == nil ? map : nil, highlightedCodes: highlightedCodes,
                backdrop: model.backdrop, photo: model.photo, boxStyle: model.boxStyle, boxPosition: model.boxPosition
            )
        }
    }
}
