import SwiftUI
import UIKit

/// 都道府県・政令指定都市のシェア用カード。区画(市区町村・区)を塗った地図を大きく描き、制覇率を主役の数字にする。
/// 都道府県の「全国の都道府県」(1.8.0 (7))は、日本地図の訪れた都道府県を塗ってその県を強く示し、訪れた都道府県の数を主役にする。
///
/// 全国のカード(`JapanStandardCard`)と同じく`ShareCardRenderer`がライト外観・文字サイズ固定で書き出す。
/// 載せるのは塗った地図と件数・称号だけで、ピン・座標・住所・訪問日時は載せない。
struct RegionStandardCard: View {
    let content: RegionShareCardContent
    let size: ShareCardSize
    /// 区画に分けた地図。読み込めなかったときはnilで、地図の枠にアイコンだけを出す(数字だけでもシェアできるようにする)。
    let map: SilhouetteMap?
    /// 地図の下に薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、図形だけの地図にする。写真があるときは使わない。
    var backdrop: ShareMapBackdrop? = nil
    /// カードいっぱいに敷く写真(1.8.0 (5))。あれば塗った地図を写真の上に描き、制覇率の箱を`boxPosition`に置く。
    var photo: UIImage? = nil
    var boxStyle: ShareCardBoxStyle = .app
    /// 写真を敷いたときの箱の位置。写真が無いときは使わない。
    var boxPosition: ShareCardBoxPosition = .bottom

    var body: some View {
        ZStack {
            if let photo {
                ShareCardPhotoBackground(photo: photo, size: size.pointSize)
            } else {
                ShareCardBackground()
            }
            switch (size, photo != nil) {
            case (.story, false): storyLayout
            case (.square, false): squareLayout
            case (.story, true): storyPhotoLayout
            case (.square, true): squarePhotoLayout
            }
        }
        .frame(width: size.pointSize.width, height: size.pointSize.height)
        .clipped()
    }

    // MARK: - 縦長

    /// 全国のカードと同じく、ストーリーズの上下に重なるアプリの表示を避けて中身を真ん中に寄せる。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                heading(size: 28, style: .app)
                dateLabel(size: 13, style: .app)
            }
            mapView(box: .regionStory)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            statsBox(percentageSize: 52, countSize: 20, padding: 14)
                .shareCardBox(boxStyle, shadow: Pop.yellow.opacity(0.8), shadowOffset: 5)
            ShareCardAppMark(logoSize: 30)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    /// 写真ありの縦長。見出しと制覇率を1つの箱にまとめて上・真ん中・下に置き、残りの広さに地図を描く。
    private var storyPhotoLayout: some View {
        VStack(spacing: 12) {
            ShareCardBoxArrangement(position: boxPosition) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        heading(size: 26, style: boxStyle)
                        dateLabel(size: 13, style: boxStyle)
                    }
                    statsBox(percentageSize: 44, countSize: 18, padding: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: 4)
            } filler: {
                photoMap
            }
            ShareCardAppMark(logoSize: 30, isOverPhoto: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 96)
    }

    /// 制覇率・件数・バー・称号と次の目標。縦長の箱の中身。
    private func statsBox(percentageSize: CGFloat, countSize: CGFloat, padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    caption(content.countCaption, style: boxStyle)
                    percentage(size: percentageSize, style: boxStyle)
                }
                Spacer(minLength: 8)
                count(size: countSize, style: boxStyle)
            }
            PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
            HStack(spacing: 10) {
                PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                nextGoal(size: 12, style: boxStyle)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 正方形

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                heading(size: 22, style: .app)
                Spacer(minLength: 8)
                dateLabel(size: 11, style: .app)
            }
            HStack(alignment: .top, spacing: 12) {
                mapView(box: .regionSquare)
                    .popCard(shadow: Pop.theme.opacity(0.35))
                // 右の列は箱に入れていないので、線の版でもアプリの色で描く(水玉の地に白い字は読めないため)。
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        caption(content.countCaption, style: .app)
                        percentage(size: 34, style: .app)
                    }
                    count(size: 14, style: .app)
                    PopProgressBar(fraction: content.fraction)
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                    nextGoal(size: 11, style: .app)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            ShareCardAppMark(logoSize: 26)
        }
        .padding(20)
    }

    private var squarePhotoLayout: some View {
        VStack(spacing: 8) {
            ShareCardBoxArrangement(position: boxPosition, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        heading(size: 20, style: boxStyle)
                        Spacer(minLength: 8)
                        dateLabel(size: 11, style: boxStyle)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // 全国の都道府県は数だけだと何の数か分からないので、「47都道府県中」を前に添える。
                        if content.kind == .nationwidePrefecture {
                            caption(content.countCaption, style: boxStyle)
                        }
                        percentage(size: 30, style: boxStyle)
                        Spacer(minLength: 8)
                        count(size: 14, style: boxStyle)
                    }
                    PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: 3)
            } filler: {
                photoMap
            }
            ShareCardAppMark(logoSize: 22, isOverPhoto: true)
        }
        .padding(18)
    }

    // MARK: - 部品

    private func heading(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        MarkerHeading(content.headline, size: size, marker: style.marker(), foreground: style.primary())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func dateLabel(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        Text(content.dateText)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(style.secondary())
            .lineLimit(1)
            .fixedSize()
    }

    /// 区画を塗った地図。読み込めなかったときは地図の枠にアイコンだけを出す。
    /// 全国のカードより区画が大きいので、隙間を埋める縁取りは少し太くてもよい。
    private func mapView(box: ShareCardMapBox) -> some View {
        ShareMapCanvas(
            map: map, visitedCodes: content.visitedCodes, emphasizedCodes: content.emphasizedCodes, box: box, backdrop: backdrop,
            outlineWidth: outlineWidth, placeholderSystemImage: placeholderSystemImage
        )
    }

    /// 写真の上に描く地図。未訪問は線だけにして写真を透かす。
    private var photoMap: some View {
        ShareCardPhotoMap(
            map: map, visitedCodes: content.visitedCodes, emphasizedCodes: content.emphasizedCodes, outlineWidth: outlineWidth,
            placeholderSystemImage: placeholderSystemImage
        )
    }

    /// 全国の都道府県は日本地図(区画が小さい)なので、全国のカードと同じく縁取りを細くする。
    private var outlineWidth: CGFloat {
        content.kind == .nationwidePrefecture ? 0.4 : 0.6
    }

    private var placeholderSystemImage: String {
        content.kind == .designatedCity ? "building.columns.fill" : "map.fill"
    }

    private func caption(_ text: String, style: ShareCardBoxStyle) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(style.secondary())
    }

    private func percentage(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        Text(content.primaryValueText)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(style.primary())
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// 「30 / 54 市区町村」。単位は都道府県なら市区町村、政令指定都市なら区。
    /// 全国の都道府県は主役の数字が都道府県の数なので、代わりに制覇率(「制覇率 25.5%」)を添える。
    @ViewBuilder
    private func count(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        if content.kind == .nationwidePrefecture {
            Text(content.secondaryValueText)
                .font(.system(size: size * 0.8, weight: .black, design: .rounded))
                .foregroundStyle(style.primary())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            fraction(size: size, style: style)
        }
    }

    private func fraction(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(content.visitedCount.formatted())
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(style.primary())
            Text("/ \(content.totalCount.formatted()) \(content.unit)")
                .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
                .foregroundStyle(style.secondary())
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func nextGoal(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        Text(content.nextGoalText)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(style.secondary())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
