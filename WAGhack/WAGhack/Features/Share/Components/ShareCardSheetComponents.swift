import SwiftUI
import UIKit

/// シェア画面の共通の骨組み。プレビュー→選択肢→注意書き→シェアするボタンの順に並べる。
///
/// 地図・市区町村のシェア(`ShareCardSheet`)とバッジのシェアで同じ並びにして、どこから開いても迷わないようにする。
/// プレビューには共有するのと同じ画像(`ShareCardRenderer`の結果)を縮めて出す。
/// 画面用に別のViewを組むと、書き出した画像と見た目がずれることがあるため。
struct ShareCardSheetScaffold<Controls: View>: View {
    let navigationTitle: String
    let footnote: String
    let rendered: RenderedShareCard?
    @Binding var size: ShareCardSize
    /// 縦長・正方形を選ばせるか。ステッカー(中身の大きさで書き出す)では出さない。
    var showsSizePicker = true
    /// プレビューをタップしたときの操作(写真の上の箱を動かす)。nilならタップできず、案内も出さない。
    var onTapPreview: (() -> Void)? = nil
    @ViewBuilder let controls: () -> Controls

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        ShareCardPreview(rendered: rendered, size: size, onTap: onTapPreview)
                        if onTapPreview != nil {
                            // 画像には入れず、プレビューの下にだけ出す。
                            Label("タップで帯を上・下に移動", systemImage: "hand.tap")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Pop.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        controls()
                        if showsSizePicker {
                            ShareCardLabeledControl("形") {
                                Picker("形", selection: $size) {
                                    ForEach(ShareCardSize.allCases) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
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
/// 背景が透明な画像(ステッカー)は、透明なところが分かるよう市松模様の上に、画像そのものの縦横比で出す。
struct ShareCardPreview: View {
    let rendered: RenderedShareCard?
    let size: ShareCardSize
    var placeholder = "カードを準備しています"
    /// タップしたときの操作。nilならただの画像。
    var onTap: (() -> Void)? = nil

    private var aspectRatio: CGFloat {
        if let rendered, rendered.isTransparent, rendered.image.size.height > 0 {
            return rendered.image.size.width / rendered.image.size.height
        }
        return size.pixelSize.width / size.pixelSize.height
    }

    var body: some View {
        Group {
            if let rendered {
                if let onTap {
                    Button(action: onTap) { image(rendered) }
                        .buttonStyle(.plain)
                        .accessibilityHint("帯の位置を上と下で入れ替えます")
                } else {
                    image(rendered)
                }
            } else {
                ProgressView(placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Pop.themeTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxHeight: 440)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: size)
    }

    private func image(_ rendered: RenderedShareCard) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Image(uiImage: rendered.image)
            .resizable()
            .scaledToFit()
            .background {
                if rendered.isTransparent { CheckerboardBackground() }
            }
            .clipShape(shape)
            .overlay(shape.stroke(Pop.border, lineWidth: 1))
            .shadow(color: .black.opacity(rendered.isTransparent ? 0 : 0.12), radius: 10, y: 4)
            .accessibilityLabel(rendered.isTransparent ? "背景が透明なステッカーのプレビュー" : "シェアする画像のプレビュー")
    }
}

/// 透明なところを示す市松模様(画像編集アプリと同じ見せ方)。プレビューにだけ使い、画像には入れない。
struct CheckerboardBackground: View {
    var squareSize: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.97)))
            let columns = Int((size.width / squareSize).rounded(.up))
            let rows = Int((size.height / squareSize).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * squareSize, y: CGFloat(row) * squareSize, width: squareSize, height: squareSize)
                    context.fill(Path(rect), with: .color(Color(white: 0.84)))
                }
            }
        }
        .accessibilityHidden(true)
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
