import SwiftUI

/// フォト: 景色を見せる(1.8.0 (7))。写真を全面に敷き、細い帯に小さな形・名前・短い一言を載せる。
///
/// 帯は下(既定)か上に置き、プレビューのタップで入れ替える。帯の見た目は「箱の見た目」(アプリの色・白の線・黒の線)。
/// 豆知識では、写真が主役のまま話のネタも伝わるよう、帯に本文の最初の一文を添える。
/// 写真が無いときは、写真の代わりにその範囲の本物の地図を薄く敷く(シェア画面では写真を選ぶよう案内する)。
struct PhotoCardLayout: View {
    let model: ShareCardModel

    private var summary: ShareCardSummary { model.summary }
    private var isStory: Bool { model.size == .story }
    private var style: ShareCardBoxStyle { model.boxStyle }

    var body: some View {
        ZStack {
            ShareCardPhotoOrMapBackground(
                photo: model.photo, backdrop: model.backdrop,
                box: ShareCardMapBox.backdropBox(for: .photo, size: model.size), size: model.size.pointSize
            )
            VStack(spacing: 0) {
                if model.boxPosition == .bottom { Spacer(minLength: 0) }
                band
                if model.boxPosition == .top { Spacer(minLength: 0) }
            }
            .padding(ShareCardInsets.of(model.size))
        }
        .frame(width: model.size.pointSize.width, height: model.size.pointSize.height)
        .clipped()
    }

    private var band: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ShareCardShapeView(shape: summary.shape, style: style.silhouetteStyle)
                    .frame(width: isStory ? 48 : 40, height: isStory ? 48 : 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name)
                        .font(.system(size: isStory ? 22 : 18, weight: .black))
                        .foregroundStyle(style.primary())
                    Text(summary.label)
                        .font(.system(size: isStory ? 13 : 12, weight: .bold, design: .rounded))
                        .foregroundStyle(style.secondary())
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                ShareCardLogoMark(size: isStory ? 22 : 18, color: style.primary())
            }
            if let topic = summary.topic {
                Text(topic.leadSentence)
                    .font(.system(size: isStory ? 15 : 12.5, weight: .medium))
                    .foregroundStyle(style.primary())
                    .lineSpacing(3)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if topic.isLegend {
                    // 伝説や噂話なので、事実と受け取られないよう注記する。
                    Text("※諸説あり")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(style.secondary())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // すりガラスは画像に書き出せないため、ほぼ白の半透明にする。
        .shareCardBox(style, fill: Color.white.opacity(0.92), shadow: Pop.theme.opacity(0.3), cornerRadius: 14, shadowOffset: 3)
    }
}
