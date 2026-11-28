import SwiftUI
import UIKit

/// 共有するカード。画像と、一緒に共有する文・共有シートの見出し。
struct RenderedShareCard {
    let image: UIImage
    let message: String
    let title: String
}

/// シェア画面の共通の骨組み。プレビュー→選択肢→注意書き→シェアするボタンの順に並べる。
///
/// 地図・市区町村のシェア(`ShareCardSheet`)とバッジのシェアで同じ並びにして、どこから開いても迷わないようにする。
/// プレビューには共有するのと同じ画像(`ShareCardRenderer`の結果)を縮めて出す。
/// 画面用に別のViewを組むと、書き出した画像と見た目がずれることがあるため。
struct ShareCardSheetScaffold<Controls: View>: View {
    let navigationTitle: String
    let footnote: String
    let rendered: RenderedShareCard?
    @Binding var layout: ShareCardLayout
    /// プレビューをタップしたときの操作(写真の上の箱を動かす)。nilならタップできず、案内も出さない。
    var onTapPreview: (() -> Void)? = nil
    @ViewBuilder let controls: () -> Controls

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        ShareCardPreview(rendered: rendered, layout: layout, onTap: onTapPreview)
                        if onTapPreview != nil {
                            // 画像には入れず、プレビューの下にだけ出す。
                            Label("タップで位置を変更", systemImage: "hand.tap")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Pop.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        controls()
                        ShareCardLabeledControl("形") {
                            Picker("形", selection: $layout) {
                                ForEach(ShareCardLayout.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    PopFootnote(footnote)
                    ShareCardShareButton(rendered: rendered)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Pop.paper.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}

/// 共有する画像のプレビュー。縦長でも画面に収まるよう高さを抑え、形の違いは縦横比で見せる。
struct ShareCardPreview: View {
    let rendered: RenderedShareCard?
    let layout: ShareCardLayout
    var placeholder = "カードを準備しています"
    /// タップしたときの操作。nilならただの画像。
    var onTap: (() -> Void)? = nil

    var body: some View {
        let size = layout.pixelSize
        Group {
            if let rendered {
                if let onTap {
                    Button(action: onTap) { image(rendered.image) }
                        .buttonStyle(.plain)
                        .accessibilityHint("箱の位置を上・真ん中・下の順に変えます")
                } else {
                    image(rendered.image)
                }
            } else {
                ProgressView(placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Pop.themeTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .frame(maxHeight: 440)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: layout)
    }

    private func image(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Pop.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .accessibilityLabel("シェアする画像のプレビュー")
    }
}

/// 共有シートを開くボタン。画像ができるまでは押せない同じ形のボタンを置き、読み込み後にレイアウトが跳ねないようにする。
/// 共有シートは`ShareCardActivity`で開く(シェアし終えた回数を数えるため。`ShareLink`では終えたかが分からない)。
struct ShareCardShareButton: View {
    let rendered: RenderedShareCard?

    var body: some View {
        Button {
            if let rendered { ShareCardActivity.present(rendered) }
        } label: {
            Label("シェアする", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .popPrimaryButton()
        .disabled(rendered == nil)
    }
}

/// シェア画面の選択肢に付ける見出し。
struct ShareCardLabeledControl<Control: View>: View {
    let title: String
    @ViewBuilder let control: () -> Control

    init(_ title: String, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.control = control
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            control()
        }
    }
}

/// カードの見出しの下に添える、日付などの小さな文字。
struct ShareCardCaption: View {
    let text: String
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Pop.muted)
            .lineLimit(1)
            .fixedSize()
    }
}
