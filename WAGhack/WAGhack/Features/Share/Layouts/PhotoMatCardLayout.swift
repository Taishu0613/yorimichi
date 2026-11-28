import SwiftUI

/// フォト・余白: 景色を作品として見せる(フィード向け、1.8.0 (7))。白い余白の中に写真を置き、
/// 下の余白に小さな形・名前・数字を1つだけ載せる。ほかの飾りは付けない。
///
/// 写真が無いときは、写真の枠にその街の本物の地図を薄く敷く(シェア画面では写真を選ぶよう案内する)。
struct PhotoMatCardLayout: View {
    let model: ShareCardModel

    private var summary: ShareCardSummary { model.summary }
    private var isStory: Bool { model.size == .story }

    /// 写真の枠。本物の地図を撮る枠(`ShareCardMapBox.photoMatStory/Square`)と同じ大きさにする。
    private var photoSize: CGSize {
        let box = ShareCardMapBox.backdropBox(for: .photoMat, size: model.size)
        return box?.size ?? .zero
    }

    var body: some View {
        VStack(spacing: isStory ? 14 : 12) {
            ShareCardPhotoOrMapBackground(
                photo: model.photo, backdrop: model.backdrop,
                box: ShareCardMapBox.backdropBox(for: .photoMat, size: model.size), size: photoSize
            )
            .frame(width: photoSize.width, height: photoSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            caption
            Spacer(minLength: 0)
        }
        // 縦長はストーリーズの上に重なるアプリの表示を避け、下の余白の文字も下の表示(約83pt)に掛けない。
        .padding(.top, isStory ? 56 : 18)
        .padding(.horizontal, isStory ? 20 : 18)
        .frame(width: model.size.pointSize.width, height: model.size.pointSize.height)
        .background(Color.white)
    }

    /// 下の余白の1行。形・名前と一言・数字・小さな印。
    private var caption: some View {
        HStack(spacing: 10) {
            ShareCardShapeView(shape: summary.shape)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Pop.inkOnAccent)
                Text(summary.label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.45))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            if let stat = summary.stat {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(stat.value)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Pop.inkOnAccent)
                        .monospacedDigit()
                    Text(stat.caption)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(white: 0.45))
                }
                .lineLimit(1)
            }
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
        }
    }
}
