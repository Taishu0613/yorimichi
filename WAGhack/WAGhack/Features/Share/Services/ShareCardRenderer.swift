import SwiftUI
import UIKit

/// シェアのカードを、SNSに載せる大きさ(1080px幅)の画像にする。
enum ShareCardRenderer {
    /// 地図・市区町村のカードを、選んだレイアウトで画像にし、一緒に共有する文を添える。
    /// ステッカーは背景を透明にし、中身の大きさで書き出す。
    /// 描けなかった場合はnil(実際には起きない想定だが、`ImageRenderer`の戻り値がOptionalのため)。
    static func render(_ model: ShareCardModel) -> RenderedShareCard? {
        let canvas = ShareCardCanvas(model: model)
        let image = model.layout.isTransparent
            ? renderTransparent(canvas, width: StickerCardLayout.width)
            : render(canvas, size: model.size)
        return image.map {
            RenderedShareCard(
                image: $0, message: model.subject.shareText, title: model.subject.shareTitle, isTransparent: model.layout.isTransparent
            )
        }
    }

    /// カードの大きさの不透明な画像にする(バッジのカードはバッジのシェア画面から直接呼ぶ)。
    /// `view`は`size.pointSize`の大きさで組んである前提。`ImageRenderer`はメインスレッドで使う必要がある。
    static func render(_ view: some View, size: ShareCardSize) -> UIImage? {
        let renderer = ImageRenderer(content: fixedAppearance(view))
        renderer.proposedSize = ProposedViewSize(size.pointSize)
        renderer.scale = ShareCardSize.renderScale
        // 背景まで塗っているので不透明にして、アルファの無い小さなPNGにする。
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// 背景が透明な画像にする(ステッカー)。横は`width`、縦は中身の高さ。
    static func renderTransparent(_ view: some View, width: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: fixedAppearance(view).fixedSize(horizontal: false, vertical: true))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = ShareCardSize.renderScale
        // アルファを残す(`isOpaque = false`は既定だが、透明が要ることを明示する)。
        renderer.isOpaque = false
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
