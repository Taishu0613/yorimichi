import SwiftUI

/// カード1枚を、選んだレイアウトで描く(1.8.0 (7))。どのカードもここを通る(`ShareCardRenderer.render(_:)`)。
///
/// レイアウトを足すときは、ここの`switch`にそのレイアウトのView(`Layouts/`の下に1レイアウト1ファイル)を足す。
/// どのレイアウトも中身の要約(`ShareCardSummary`)だけで描くので、中身の種類ごとの描き分けは要らない。
struct ShareCardCanvas: View {
    let model: ShareCardModel

    var body: some View {
        switch model.layout {
        case .photo: PhotoCardLayout(model: model)
        case .photoMat: PhotoMatCardLayout(model: model)
        case .sticker: StickerCardLayout(model: model)
        case .number: NumberCardLayout(model: model)
        case .map: MapCardLayout(model: model)
        case .reading: ReadingCardLayout(model: model)
        }
    }
}
