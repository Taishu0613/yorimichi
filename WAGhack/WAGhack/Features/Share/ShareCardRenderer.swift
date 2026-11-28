import SwiftUI
import UIKit

/// `ShareCardView`を、SNSに載せる大きさ(1080px幅)の画像にする。
enum ShareCardRenderer {
    /// カードを画像にする。`ImageRenderer`はメインスレッドで使う必要がある。
    /// 描けなかった場合はnil(実際には起きない想定だが、`ImageRenderer`の戻り値がOptionalのため)。
    static func render(
        content: ShareCardContent, layout: ShareCardLayout, fill: ShareCardFill, maps: ShareCardMaps, backdrop: ShareMapBackdrop? = nil
    ) -> UIImage? {
        render(ShareCardView(content: content, layout: layout, fill: fill, maps: maps, backdrop: backdrop), layout: layout)
    }

    /// 都道府県・政令指定都市のカードを画像にする。
    static func render(
        content: RegionShareCardContent, layout: ShareCardLayout, map: SilhouetteMap?, backdrop: ShareMapBackdrop? = nil
    ) -> UIImage? {
        render(RegionShareCardView(content: content, layout: layout, map: map, backdrop: backdrop), layout: layout)
    }

    /// どのカードも、この共通の書き出しを通す(バッジ・豆知識・初訪問のカードは各シートから直接呼ぶ)。
    /// `view`は`layout.pointSize`の大きさで組んである前提。
    static func render(_ view: some View, layout: ShareCardLayout) -> UIImage? {
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
