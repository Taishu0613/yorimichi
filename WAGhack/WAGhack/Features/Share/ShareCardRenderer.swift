import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// `ShareCardView`を、SNSに載せる大きさ(1080px幅)の画像にする。
enum ShareCardRenderer {
    /// カードを画像にする。`ImageRenderer`はメインスレッドで使う必要がある。
    /// 描けなかった場合はnil(実際には起きない想定だが、`ImageRenderer`の戻り値がOptionalのため)。
    static func render(content: ShareCardContent, layout: ShareCardLayout, fill: ShareCardFill, maps: ShareCardMaps) -> UIImage? {
        render(ShareCardView(content: content, layout: layout, fill: fill, maps: maps), layout: layout)
    }

    /// 都道府県・政令指定都市のカードを画像にする。
    static func render(content: RegionShareCardContent, layout: ShareCardLayout, map: SilhouetteMap?) -> UIImage? {
        render(RegionShareCardView(content: content, layout: layout, map: map), layout: layout)
    }

    private static func render(_ view: some View, layout: ShareCardLayout) -> UIImage? {
        let card = view
            // 端末の外観・文字サイズによらず同じ画像になるよう固定する(理由は`ShareCardView`の説明)。
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(layout.pointSize)
        renderer.scale = ShareCardLayout.renderScale
        // 背景まで塗っているので不透明にして、アルファの無い小さなPNGにする。
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// 共有シートに渡す画像。PNGで渡し、「画像を保存」やSNSのアプリで受け取れるようにする。
nonisolated struct ShareCardImage: Transferable {
    enum ExportError: Error {
        case encodingFailed
    }

    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        // PNGへの変換(1080×1920で数十ms)は、共有先が画像を求めたときにだけ行う。
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.image.pngData() else { throw ExportError.encodingFailed }
            return data
        }
        .suggestedFileName("yorimichi-map.png")
    }
}
