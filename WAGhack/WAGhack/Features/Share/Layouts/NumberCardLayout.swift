import SwiftUI

/// 数字: 制覇を自慢する(1.8.0 (7))。主役の数字(「55.1%」「12/47」)を大きく、塗った形を中くらい、
/// 補足(「38 / 69 市区町村」)を1行。写真は選べば薄く敷く。
struct NumberCardLayout: View {
    let model: ShareCardModel

    private var summary: ShareCardSummary { model.summary }

    var body: some View {
        ZStack {
            background
            switch model.size {
            case .story: storyLayout
            case .square: squareLayout
            }
        }
        .frame(width: model.size.pointSize.width, height: model.size.pointSize.height)
        .clipped()
    }

    @ViewBuilder
    private var background: some View {
        if let photo = model.photo {
            // 数字と形が主役なので、写真は白で薄めて地にする。
            ShareCardPhotoBackground(photo: photo, size: model.size.pointSize)
            Color.white.opacity(0.78)
        } else {
            ShareCardBackground()
        }
    }

    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkerHeading(summary.headline, size: 24)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            numberBlock(valueSize: 92, captionSize: 15, detailSize: 18)
                .padding(.top, 28)
            Spacer(minLength: 16)
            ShareCardShapeView(shape: summary.shape)
                .frame(maxWidth: .infinity, maxHeight: 230)
            Spacer(minLength: 16)
            ShareCardAppMark(logoSize: 26)
        }
        .padding(ShareCardInsets.of(.story))
    }

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkerHeading(summary.headline, size: 20)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(alignment: .center, spacing: 12) {
                numberBlock(valueSize: 60, captionSize: 13, detailSize: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ShareCardShapeView(shape: summary.shape)
                    .frame(width: 140, height: 190)
            }
            .frame(maxHeight: .infinity)
            ShareCardAppMark(logoSize: 22)
        }
        .padding(EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22))
    }

    @ViewBuilder
    private func numberBlock(valueSize: CGFloat, captionSize: CGFloat, detailSize: CGFloat) -> some View {
        if let stat = summary.stat {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.caption)
                    .font(.system(size: captionSize, weight: .heavy))
                    .foregroundStyle(Pop.muted)
                Text(stat.value)
                    .font(.system(size: valueSize, weight: .black, design: .rounded))
                    .foregroundStyle(Pop.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                if let detail = stat.detail {
                    Text(detail)
                        .font(.system(size: detailSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Pop.muted)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }
}
