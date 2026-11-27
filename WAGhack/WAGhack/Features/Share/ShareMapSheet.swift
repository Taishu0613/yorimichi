import SwiftUI

/// 旅の記録の「地図をシェア」から開く画面。カードの形と塗りを選び、できた画像をそのまま確かめてから共有する。
///
/// プレビューには共有するのと同じ画像(`ShareCardRenderer`の結果)を縮めて出す。
/// 画面用に別のViewを組むと、書き出した画像と見た目がずれることがあるため。
struct ShareMapSheet: View {
    let content: ShareCardContent
    /// 旅の記録から受け取る。プレビューなど渡されない場所では、この画面で作ったものを使う。
    let silhouetteStore: SilhouetteMapStore?

    @State private var layout: ShareCardLayout = .story
    @State private var fill: ShareCardFill = .municipalities
    /// 選んだ形・塗りで描いた画像。形か塗りを変えるたびに描き直す。
    @State private var renderedImage: UIImage?
    @State private var fallbackStore = SilhouetteMapStore()
    @Environment(\.dismiss) private var dismiss

    private var store: SilhouetteMapStore { silhouetteStore ?? fallbackStore }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    preview
                    VStack(alignment: .leading, spacing: 14) {
                        labeled("形") {
                            Picker("形", selection: $layout) {
                                ForEach(ShareCardLayout.allCases) { Text($0.title).tag($0) }
                            }
                        }
                        labeled("塗り") {
                            Picker("塗り", selection: $fill) {
                                ForEach(ShareCardFill.allCases) { Text($0.title).tag($0) }
                            }
                        }
                    }
                    PopFootnote("画像には塗った地図と件数だけが入ります。ピン・住所・訪れた日時は入りません。")
                    shareButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Pop.paper.ignoresSafeArea())
            .navigationTitle("地図をシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task { await store.loadShareCardMapsIfNeeded() }
        // 地図の読み込みが終わったとき・形や塗りを変えたときに描き直す。
        .task(id: RenderKey(layout: layout, fill: fill, isMapReady: store.shareCardMaps != nil)) {
            render()
        }
    }

    private struct RenderKey: Hashable {
        let layout: ShareCardLayout
        let fill: ShareCardFill
        let isMapReady: Bool
    }

    private func render() {
        guard let maps = store.shareCardMaps else {
            renderedImage = nil
            return
        }
        renderedImage = ShareCardRenderer.render(content: content, layout: layout, fill: fill, maps: maps)
    }

    /// 縦長でも画面に収まるよう高さを抑え、形の違いは縦横比で見せる。
    private var preview: some View {
        let size = layout.pixelSize
        return Group {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Pop.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .accessibilityLabel("シェアする画像のプレビュー")
            } else {
                ProgressView("日本地図を準備しています")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Pop.themeTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .frame(maxHeight: 440)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: layout)
    }

    private func labeled(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            picker()
                .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let renderedImage {
            ShareLink(
                item: ShareCardImage(image: renderedImage),
                message: Text(content.shareText),
                preview: SharePreview("わたしの日本地図", image: Image(uiImage: renderedImage))
            ) {
                Label("シェアする", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .popPrimaryButton()
        } else {
            // 画像ができるまでは押せない同じ形のボタンを置き、読み込み後にレイアウトが跳ねないようにする。
            Button {} label: {
                Label("シェアする", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .popPrimaryButton()
            .disabled(true)
        }
    }
}
