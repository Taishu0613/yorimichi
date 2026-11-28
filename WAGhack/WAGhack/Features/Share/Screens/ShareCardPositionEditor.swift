import SwiftUI

/// 「位置を調整」の画面(1.8.0 (10))。写真を敷いたカードの上で、箱と形(ポリゴン)を指で動かす・2本指で大きさを変える。
///
/// (8)の「ステッカーを貼る」の画面を作り変えたもの(「ステッカーを少し変えて位置を変える機能にしたい」との声)。
/// プレビューは書き出すのと同じView(`ShareCardCanvas`)をカードの大きさ(pt)で組み、画面の幅に縮めて見せる。
/// 指の動きは縮めた分を戻してカードの座標に直す。どちらを動かすかは上の切り替えで選ぶ(指の下にあるものを探さずに済むので、
/// 形が箱に重なっていても、カードの外へ出しかけても、プレビューのどこを触っても動かせる)。
/// 調整した位置はシェア画面の状態(`adjustment`)に書き戻し、シェアする画像に使う。
struct ShareCardPositionEditor: View {
    /// 調整するカード。`adjustment`はこの画面のものに差し替えて描く。
    let model: ShareCardModel
    @Binding var adjustment: ShareCardAdjustment

    @State private var element: ShareCardElement = .box
    /// 指を動かしている間の、動かし始めの位置・大きさ。ドラッグとピンチは同時に動くので別々に持つ。
    @State private var dragStart: ShareCardElementPlacement?
    @State private var magnifyStart: ShareCardElementPlacement?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ShareCardSegmentedControl(title: "動かすもの", selection: $element, options: ShareCardElement.allCases, label: \.title)
                    VStack(spacing: 8) {
                        preview
                        Label("ドラッグで動かす・ピンチで大きさを変える", systemImage: "hand.draw")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Pop.muted)
                    }
                    Button("元の位置に戻す", systemImage: "arrow.counterclockwise") {
                        adjustment = .none
                    }
                    .buttonStyle(.bordered)
                    .tint(Pop.muted)
                    .disabled(!adjustment.isAdjusted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            // プレビューの上で指を動かしてもスクロールしないようにする(縦にドラッグすると箱より先にスクロールが動くため)。
            .scrollDisabled(dragStart != nil || magnifyStart != nil)
            .background(Pop.paper.ignoresSafeArea())
            .navigationTitle("位置を調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    private var adjustedModel: ShareCardModel {
        var adjusted = model
        adjusted.adjustment = adjustment
        return adjusted
    }

    private var preview: some View {
        let cardSize = model.size.pointSize
        return GeometryReader { proxy in
            let displayScale = min(proxy.size.width / cardSize.width, proxy.size.height / cardSize.height)
            ShareCardCanvas(model: adjustedModel)
                .frame(width: cardSize.width, height: cardSize.height)
                .environment(\.colorScheme, .light)
                .dynamicTypeSize(.large)
                .scaleEffect(displayScale, anchor: .topLeading)
                .frame(width: cardSize.width * displayScale, height: cardSize.height * displayScale, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = dragStart ?? adjustment[element]
                            dragStart = start
                            let translation = CGSize(width: value.translation.width / displayScale, height: value.translation.height / displayScale)
                            var moved = start.moved(by: translation, in: cardSize)
                            moved.scale = adjustment[element].scale
                            adjustment[element] = moved
                        }
                        .onEnded { _ in dragStart = nil }
                        .simultaneously(with: MagnifyGesture()
                            .onChanged { value in
                                let start = magnifyStart ?? adjustment[element]
                                magnifyStart = start
                                var scaled = start.scaled(by: value.magnification)
                                scaled.unitOffset = adjustment[element].unitOffset
                                adjustment[element] = scaled
                            }
                            .onEnded { _ in magnifyStart = nil }
                        )
                )
                .frame(maxWidth: .infinity)
                .accessibilityLabel("位置を調整しているカードのプレビュー")
        }
        .aspectRatio(cardSize.width / cardSize.height, contentMode: .fit)
        .frame(maxHeight: 460)
    }
}
