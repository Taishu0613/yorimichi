import SwiftUI

/// 読み物: みどころ・都市伝説・この街でできることを読んでもらう(1.8.0 (7))。本文を大きく読みやすく描き、
/// 見出しに名前と小さな形を添える。写真を選んだら、上に細い帯で見せる。
///
/// 都市伝説は図鑑と同じ夜色にして「※諸説あり」を添える。この街でできることは、選んだスポットの名前と一言。
struct ReadingCardLayout: View {
    let model: ShareCardModel

    private var summary: ShareCardSummary { model.summary }
    private var isStory: Bool { model.size == .story }
    private var isLegend: Bool { summary.topic?.isLegend ?? false }
    private var textColor: Color { isLegend ? Pop.onNight : Pop.inkOnAccent }
    private var subColor: Color { isLegend ? Pop.onNight.opacity(0.7) : Color(white: 0.45) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let photo = model.photo {
                ShareCardPhotoBackground(photo: photo, size: CGSize(width: model.size.pointSize.width, height: isStory ? 150 : 84))
            }
            VStack(alignment: .leading, spacing: isStory ? 18 : 10) {
                header
                bodyText
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if isLegend {
                    // 伝説や噂話なので、事実と受け取られないよう注記する。
                    Text("※諸説あり")
                        .font(.system(size: isStory ? 12 : 10, weight: .bold))
                        .foregroundStyle(subColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ShareCardAppMark(logoSize: isStory ? 24 : 20, isOverPhoto: isLegend)
            }
            .padding(.horizontal, isStory ? 28 : 20)
            .padding(.top, model.photo != nil ? (isStory ? 20 : 12) : (isStory ? 64 : 20))
            .padding(.bottom, isStory ? 96 : 18)
        }
        .frame(width: model.size.pointSize.width, height: model.size.pointSize.height, alignment: .top)
        .background(isLegend ? Pop.night : Color.white)
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ShareCardShapeView(shape: summary.shape, style: isLegend ? .overPhoto : .solid)
                .frame(width: isStory ? 52 : 38, height: isStory ? 52 : 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.label)
                    .font(.system(size: isStory ? 13 : 11, weight: .heavy))
                    .foregroundStyle(isLegend ? Pop.onNight.opacity(0.8) : Pop.theme)
                Text(summary.name)
                    .font(.system(size: isStory ? 28 : 21, weight: .black))
                    .foregroundStyle(textColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    /// 本文。マスタの文はおよそ190字までなので、収まらなければ少しだけ小さくして全文を載せる。
    @ViewBuilder
    private var bodyText: some View {
        switch summary.topic?.topic {
        case .highlights(let text)?, .legend(let text)?:
            paragraph(text, size: isStory ? 18 : 13.5)
        case .spot(let name, let line)?:
            VStack(alignment: .leading, spacing: isStory ? 12 : 6) {
                Text(name)
                    .font(.system(size: isStory ? 30 : 22, weight: .black))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !line.isEmpty {
                    paragraph(line, size: isStory ? 18 : 14)
                }
            }
        case nil:
            EmptyView()
        }
    }

    private func paragraph(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(textColor)
            .lineSpacing(size * 0.45)
            .minimumScaleFactor(0.65)
    }
}
