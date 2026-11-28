import SwiftUI
import UIKit

/// シェアのカードを、SNSに載せる大きさ(1080px幅)の画像にする。
enum ShareCardRenderer {
    /// 地図・市区町村のカードを画像にし、一緒に共有する文を添える。
    /// 描けなかった場合はnil(実際には起きない想定だが、`ImageRenderer`の戻り値がOptionalのため)。
    static func render(_ model: ShareCardModel) -> RenderedShareCard? {
        render(ShareCardCanvas(model: model), size: model.size).map {
            RenderedShareCard(image: $0, message: model.subject.shareText, title: model.subject.shareTitle)
        }
    }

    /// カードの大きさの不透明な画像にする(バッジのカード・ステッカーを貼った写真はそれぞれの画面から直接呼ぶ)。
    /// `view`は`size.pointSize`の大きさで組んである前提。`ImageRenderer`はメインスレッドで使う必要がある。
    static func render(_ view: some View, size: ShareCardSize) -> UIImage? {
        let renderer = ImageRenderer(content: fixedAppearance(view))
        renderer.proposedSize = ProposedViewSize(size.pointSize)
        renderer.scale = ShareCardSize.renderScale
        // 背景まで塗っているので不透明にして、アルファの無い小さなPNGにする。
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// 端末の外観・文字サイズによらず同じ画像になるよう固定する。ダークモードの人が作っても同じカードにし、
    /// 文字を大きくしている人の画像だけ枠からはみ出さないようにする。
    private static func fixedAppearance(_ view: some View) -> some View {
        view
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
    }
}
