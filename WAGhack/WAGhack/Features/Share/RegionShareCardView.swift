import SwiftUI

/// 都道府県・政令指定都市のシェア用カード。区画(市区町村・区)を塗った地図を大きく描き、制覇率を主役の数字にする。
///
/// 全国のカード(`ShareCardView`)と同じく`ShareCardRenderer`がライト外観・文字サイズ固定で書き出す。
/// 載せるのは塗った地図と件数・称号だけで、ピン・座標・住所・訪問日時は載せない。
struct RegionShareCardView: View {
    let content: RegionShareCardContent
    let layout: ShareCardLayout
    /// 区画に分けた地図。読み込めなかったときはnilで、地図の枠にアイコンだけを出す(数字だけでもシェアできるようにする)。
    let map: SilhouetteMap?
    /// 地図の下に薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、図形だけの地図にする。
    var backdrop: ShareMapBackdrop? = nil

    var body: some View {
        Group {
            switch layout {
            case .story: storyLayout
            case .square: squareLayout
            }
        }
        .frame(width: layout.pointSize.width, height: layout.pointSize.height)
        .background(ShareCardBackground())
    }

    // MARK: - 縦長

    /// 全国のカードと同じく、ストーリーズの上下に重なるアプリの表示を避けて中身を真ん中に寄せる。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                heading(size: 28)
                dateLabel(size: 13)
            }
            mapView(box: .regionStory)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        caption("制覇率")
                        percentage(size: 52)
                    }
                    Spacer(minLength: 8)
                    count(size: 20)
                }
                PopProgressBar(fraction: content.fraction)
                HStack(spacing: 10) {
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                    nextGoal(size: 12)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .popCard(shadow: Pop.yellow.opacity(0.8), shadowOffset: 5)
            ShareCardAppMark(logoSize: 30)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    // MARK: - 正方形

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                heading(size: 22)
                Spacer(minLength: 8)
                dateLabel(size: 11)
            }
            HStack(alignment: .top, spacing: 12) {
                mapView(box: .regionSquare)
                    .popCard(shadow: Pop.theme.opacity(0.35))
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        caption("制覇率")
                        percentage(size: 34)
                    }
                    count(size: 14)
                    PopProgressBar(fraction: content.fraction)
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                    nextGoal(size: 11)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            ShareCardAppMark(logoSize: 26)
        }
        .padding(20)
    }

    // MARK: - 部品

    private func heading(size: CGFloat) -> some View {
        MarkerHeading(content.headline, size: size)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func dateLabel(size: CGFloat) -> some View {
        Text(content.dateText)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Pop.muted)
            .lineLimit(1)
            .fixedSize()
    }

    /// 区画を塗った地図。読み込めなかったときは地図の枠にアイコンだけを出す。
    /// 全国のカードより区画が大きいので、隙間を埋める縁取りは少し太くてもよい。
    private func mapView(box: ShareCardMapBox) -> some View {
        ShareMapCanvas(
            map: map, visitedCodes: content.visitedCodes, box: box, backdrop: backdrop, outlineWidth: 0.6,
            placeholderSystemImage: content.kind == .prefecture ? "map.fill" : "building.columns.fill"
        )
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Pop.muted)
    }

    private func percentage(size: CGFloat) -> some View {
        Text(content.percentageText)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(Pop.ink)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// 「30 / 54 市区町村」。単位は都道府県なら市区町村、政令指定都市なら区。
    private func count(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(content.visitedCount.formatted())
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(Pop.ink)
            Text("/ \(content.totalCount.formatted()) \(content.unit)")
                .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
                .foregroundStyle(Pop.muted)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func nextGoal(size: CGFloat) -> some View {
        Text(content.nextGoalText)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(Pop.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
