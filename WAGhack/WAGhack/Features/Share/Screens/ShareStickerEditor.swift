import SwiftUI
import UIKit

/// 「ステッカーを貼る」の画面(1.8.0 (8))。選んだ写真の上に形・名前・数字のステッカーを置き、
/// 指で動かす・2本指で拡大縮小して、その合成画像をシェアする。
///
/// プレビューは書き出すのと同じView(`ShareStickerCanvas`)をカードの大きさ(pt)で組み、画面の幅に縮めて見せる。
/// 指の動きは縮めた分を戻してカードの座標に直す。箱の見た目と縦長・正方形はシェア画面と共通(Bindingで受け取る)。
struct ShareStickerEditor: View {
    let photo: UIImage
    let summary: ShareCardSummary
    let shape: ShareCardShape
    let shareText: String
    let shareTitle: String
    @Binding var boxStyle: ShareCardBoxStyle
    @Binding var size: ShareCardSize

    @State private var placement = ShareStickerPlacement()
    /// 指を動かしている間の、動かし始めの位置・大きさ。ドラッグとピンチは同時に動くので別々に持つ。
    @State private var dragStart: CGPoint?
    @State private var magnifyStart: CGFloat?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        preview
                        Label("ドラッグで動かす・ピンチで大きさを変える", systemImage: "hand.draw")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Pop.muted)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ShareCardSegmentedControl(title: "箱の見た目", selection: $boxStyle, options: ShareCardBoxStyle.allCases, label: \.title)
                        ShareCardSizePicker(size: $size)
                    }
                    Button {
                        if let card = render() { ShareCardActivity.present(card) }
                    } label: {
                        Label("シェアする", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .popPrimaryButton()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            // プレビューの上で指を動かしてもスクロールしないようにする(縦にドラッグするとステッカーより先にスクロールが動くため)。
            .scrollDisabled(dragStart != nil || magnifyStart != nil)
            .background(Pop.paper.ignoresSafeArea())
            .navigationTitle("ステッカーを貼る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private var canvas: ShareStickerCanvas {
        ShareStickerCanvas(photo: photo, summary: summary, shape: shape, boxStyle: boxStyle, size: size, placement: placement)
    }

    private var preview: some View {
        let cardSize = size.pointSize
        return GeometryReader { proxy in
            let displayScale = min(proxy.size.width / cardSize.width, proxy.size.height / cardSize.height)
            canvas
                .environment(\.colorScheme, .light)
                .scaleEffect(displayScale, anchor: .topLeading)
                .frame(width: cardSize.width * displayScale, height: cardSize.height * displayScale, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = dragStart ?? placement.unitCenter
                            dragStart = start
                            let translation = CGSize(width: value.translation.width / displayScale, height: value.translation.height / displayScale)
                            var moved = placement
                            moved.unitCenter = start
                            placement = moved.moved(by: translation, in: cardSize)
                        }
                        .onEnded { _ in dragStart = nil }
                        .simultaneously(with: MagnifyGesture()
                            .onChanged { value in
                                let start = magnifyStart ?? placement.scale
                                magnifyStart = start
                                var scaled = placement
                                scaled.scale = start
                                placement = scaled.scaled(by: value.magnification)
                            }
                            .onEnded { _ in magnifyStart = nil }
                        )
                )
                .frame(maxWidth: .infinity)
                .accessibilityLabel("ステッカーを貼った写真のプレビュー")
        }
        .aspectRatio(cardSize.width / cardSize.height, contentMode: .fit)
        .frame(maxHeight: 460)
    }

    private func render() -> RenderedShareCard? {
        ShareCardRenderer.render(canvas, size: size).map {
            RenderedShareCard(image: $0, message: shareText, title: shareTitle)
        }
    }
}
