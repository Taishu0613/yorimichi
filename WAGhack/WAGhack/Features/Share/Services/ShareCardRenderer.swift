import SwiftUI
import UIKit

/// シェアのカードを、SNSに載せる大きさ(1080px幅)の画像にする。
enum ShareCardRenderer {
    /// 地図・市区町村のカードを、選んだレイアウトで画像にし、一緒に共有する文を添える。
    /// 描けなかった場合はnil(実際には起きない想定だが、`ImageRenderer`の戻り値がOptionalのため)。
    static func render(_ model: ShareCardModel) -> RenderedShareCard? {
        render(ShareCardCanvas(model: model), size: model.size).map {
            RenderedShareCard(image: $0, message: model.subject.shareText, title: model.subject.shareTitle)
        }
    }

    /// どのカードも、この共通の書き出しを通す(バッジのカードはバッジのシェア画面から直接呼ぶ)。
    /// `view`は`size.pointSize`の大きさで組んである前提。`ImageRenderer`はメインスレッドで使う必要がある。
    static func render(_ view: some View, size: ShareCardSize) -> UIImage? {
        let card = view
            // 端末の外観・文字サイズによらず同じ画像になるよう固定する(理由は`JapanStandardCard`の説明)。
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(size.pointSize)
        renderer.scale = ShareCardSize.renderScale
        // 背景まで塗っているので不透明にして、アルファの無い小さなPNGにする。
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
