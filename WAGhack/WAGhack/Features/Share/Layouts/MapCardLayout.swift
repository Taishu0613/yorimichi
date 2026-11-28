import SwiftUI

/// 地図: どこへ行ったかを見せる(1.8.0 (7))。塗った形をカードいっぱいに大きく描き、見出しと数字は左上の小さな箱に。
///
/// 地は写真(選んだとき)か、その範囲の本物の地図を薄く(撮れるまでは水玉の地)。箱は「箱の見た目」に従う。
struct MapCardLayout: View {
    let model: ShareCardModel

    private var summary: ShareCardSummary { model.summary }
    private var isStory: Bool { model.size == .story }
    private var style: ShareCardBoxStyle { model.boxStyle }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let photo = model.photo {
                ShareCardPhotoBackground(photo: photo, size: model.size.pointSize)
            } else {
                ShareCardBackground()
            }
            if let box = ShareCardMapBox.backdropBox(for: .map, size: model.size) {
                ShareMapCanvas(
                    map: summary.shape.map, visitedCodes: summary.shape.filledCodes, emphasizedCodes: summary.shape.emphasizedCodes,
                    box: box, backdrop: model.photo == nil ? model.backdrop : nil, outlineWidth: summary.shape.outlineWidth,
                    placeholderSystemImage: summary.shape.placeholderSystemImage, cornerRadius: 0,
                    isOverPhoto: model.photo != nil, overPhotoStyle: style.silhouetteStyle
                )
            }
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 0)
                ShareCardAppMark(logoSize: isStory ? 26 : 22, isOverPhoto: model.photo != nil || model.backdrop != nil)
            }
            .padding(ShareCardInsets.of(model.size))
        }
        .frame(width: model.size.pointSize.width, height: model.size.pointSize.height)
        .clipped()
    }

    /// 見出しと小さな数字。写真や地図を隠さないよう、中身の幅だけの箱にする。
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.headline)
                .font(.system(size: isStory ? 20 : 17, weight: .black))
                .foregroundStyle(style.primary())
            if let stat = summary.stat {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(stat.value)
                        .font(.system(size: isStory ? 20 : 17, weight: .black, design: .rounded))
                        .foregroundStyle(style.primary(Pop.theme))
                        .monospacedDigit()
                    Text(stat.detail ?? stat.caption)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(style.secondary())
                        .monospacedDigit()
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .shareCardBox(style, fill: Color.white.opacity(0.92), shadow: Pop.theme.opacity(0.3), cornerRadius: 14, shadowOffset: 3)
    }
}
