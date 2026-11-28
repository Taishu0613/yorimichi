import SwiftUI

/// ステッカー: 自分のカメラの写真に貼る(Instagramのストーリーズのスタンプ、1.8.0 (7))。
/// 背景が透明なPNGに、形・名前・数字1つだけを描く。
///
/// 中身の大きさで書き出す(横`width`、縦は中身に合わせる)ので、縦長・正方形は選ばない。
/// 見た目は「箱の見た目」に従う。白の線(初めの見た目)は白い字と線に薄い影、黒の線は黒い字と線、アプリの色は白い札に載せる。
struct StickerCardLayout: View {
    let model: ShareCardModel

    /// 書き出す横幅(pt)。3倍で900px。ストーリーズに貼って指で大きさを変えられる程度にする。
    static let width: CGFloat = 300
    private static let shapeWidth: CGFloat = 240
    private static let maxShapeHeight: CGFloat = 230

    private var summary: ShareCardSummary { model.summary }
    private var style: ShareCardBoxStyle { model.boxStyle }

    private var shapeHeight: CGFloat {
        guard let map = summary.shape.map, map.aspectRatio > 0 else { return 120 }
        return min(Self.maxShapeHeight, Self.shapeWidth / map.aspectRatio)
    }

    var body: some View {
        content
            .padding(18)
            .background {
                if style == .app {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Pop.border, lineWidth: Pop.borderWidth))
                }
            }
            // 影が切れないよう、外側に少し余白を残す(透明なので貼っても見えない)。
            .padding(8)
            .frame(width: Self.width)
    }

    private var content: some View {
        VStack(spacing: 8) {
            ShareCardShapeView(shape: summary.shape, style: style.silhouetteStyle)
                .frame(width: Self.shapeWidth, height: shapeHeight)
            Text(summary.name)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(style.primary())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let stat = summary.stat {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(stat.value)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(style.primary())
                    Text(stat.caption)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(style.secondary())
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .compositingGroup()
        // 白の線は明るい写真の上でも読めるよう、字と線にまとめて薄い影を落とす。
        .shadow(color: style == .whiteLine ? .black.opacity(0.45) : .clear, radius: 2.5, y: 1)
    }
}
