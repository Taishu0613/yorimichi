import SwiftUI
import UIKit

/// 都道府県・政令指定都市のシェア用カード。区画(市区町村・区)を塗った地図を大きく描き、制覇率を主役の数字にする。
///
/// 1.8.0 (6)の見た目。「全国の都道府県」(1.8.0 (7))も同じ形で、日本地図の都道府県を塗ってその県を強く示す。
/// 「日本の中の位置」を選ぶと、見出しの右に日本地図の中のその県を小さく添える(`ShareCardModel.boxShape`)。
/// 写真ありは上に塗った地図を大きく、その下に箱(標準・小さい箱、1.8.0 (10))。
/// 載せるのは塗った地図と件数・称号だけで、ピン・座標・住所・訪問日時は載せない。
struct RegionShareCardView: View {
    let content: RegionShareCardContent
    /// 区画に分けた地図。読み込めなかったときはnilで、地図の枠にアイコンだけを出す(数字だけでもシェアできるようにする)。
    let map: SilhouetteMap?
    let model: ShareCardModel

    private var layout: ShareCardSize { model.size }
    private var backdrop: ShareMapBackdrop? { model.backdrop }
    private var photo: UIImage? { model.photo }
    private var boxStyle: ShareCardBoxStyle { model.effectiveBoxStyle }
    private var isStory: Bool { layout == .story }

    var body: some View {
        ZStack {
            if let photo {
                ShareCardPhotoBackground(photo: photo, size: layout.pointSize)
            } else {
                ShareCardBackground()
            }
            switch (layout, photo != nil) {
            case (.story, false): storyLayout
            case (.square, false): squareLayout
            case (_, true): photoLayout
            }
        }
        .frame(width: layout.pointSize.width, height: layout.pointSize.height)
        .clipped()
    }

    // MARK: - 縦長

    /// 全国のカードと同じく、ストーリーズの上下に重なるアプリの表示を避けて中身を真ん中に寄せる。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    heading(size: 28, style: .app)
                    dateLabel(size: 13, style: .app)
                }
                Spacer(minLength: 0)
                locator(side: 52, style: .app)
            }
            mapView(box: .regionStory)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            statsBox(percentageSize: 52, countSize: 20, padding: 14)
                .shareCardBox(boxStyle, shadow: Pop.yellow.opacity(0.8), shadowOffset: 5)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    /// 制覇率・件数・バー・称号と次の目標。縦長の箱の中身。
    private func statsBox(percentageSize: CGFloat, countSize: CGFloat, padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    caption("制覇率", style: boxStyle)
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
            HStack(alignment: .center) {
                heading(size: 22, style: .app)
                Spacer(minLength: 8)
                dateLabel(size: 11, style: .app)
                locator(side: 30, style: .app)
            }
            HStack(alignment: .top, spacing: 12) {
                mapView(box: .regionSquare)
                    .popCard(shadow: Pop.theme.opacity(0.35))
                // 右の列は箱に入れていないので、線の版でもアプリの色で描く(水玉の地に白い字は読めないため)。
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        caption("制覇率", style: .app)
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
        }
        .padding(20)
        // 右下の角のアプリ名(`ShareCardCanvas`)に掛けない。
        .padding(.bottom, 22)
    }

    // MARK: - 写真あり(1.8.0 (10))

    /// 上に塗った地図を大きく、その下に見出しと制覇率の箱。
    private var photoLayout: some View {
        ShareCardPhotoComposition(size: layout, adjustment: model.adjustment, spacing: isStory ? 12 : 8) {
            photoMap
        } box: {
            switch model.boxSize {
            case .standard: standardBox
            case .compact: compactBox
            }
        }
    }

    /// 標準: (9)の箱の中身のまま、余白と文字を少し詰める。
    private var standardBox: some View {
        VStack(alignment: .leading, spacing: isStory ? 8 : 5) {
            HStack(alignment: .center, spacing: 8) {
                if isStory {
                    VStack(alignment: .leading, spacing: 2) {
                        heading(size: 22, style: boxStyle)
                        dateLabel(size: 12, style: boxStyle)
                    }
                    Spacer(minLength: 8)
                } else {
                    heading(size: 18, style: boxStyle)
                    Spacer(minLength: 8)
                    dateLabel(size: 10, style: boxStyle)
                }
                locator(side: isStory ? 40 : 26, style: boxStyle)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    if isStory { caption("制覇率", style: boxStyle) }
                    percentage(size: isStory ? 38 : 28, style: boxStyle)
                }
                Spacer(minLength: 8)
                count(size: isStory ? 16 : 13, style: boxStyle)
            }
            PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
            HStack(spacing: 8) {
                PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                if isStory { nextGoal(size: 11, style: boxStyle) }
            }
        }
        .padding(isStory ? 12 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: isStory ? 4 : 3)
    }

    /// 小さい箱: 見出しと日付を1行に、大きな制覇率の右にn/Nを縦に添え、細い棒。
    /// 達成の札と「あと何市区町村で」は載せない(「そこはいらない」との声)。
    private var compactBox: some View {
        VStack(alignment: .leading, spacing: isStory ? 4 : 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                heading(size: isStory ? 16 : 14, style: boxStyle)
                Spacer(minLength: 6)
                dateLabel(size: isStory ? 10 : 9, style: boxStyle)
            }
            HStack(alignment: .center, spacing: 8) {
                percentage(size: isStory ? 34 : 26, style: boxStyle)
                VStack(alignment: .leading, spacing: 0) {
                    Text(content.visitedCount.formatted())
                        .font(.system(size: isStory ? 16 : 13, weight: .black, design: .rounded))
                        .foregroundStyle(boxStyle.primary())
                    Text("/ \(content.totalCount.formatted()) \(content.unit)")
                        .font(.system(size: isStory ? 10 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(boxStyle.secondary())
                }
                .monospacedDigit()
                .lineLimit(1)
                Spacer(minLength: 0)
                locator(side: isStory ? 30 : 24, style: boxStyle)
            }
            ShareCardThinProgressBar(fraction: content.fraction, style: boxStyle, height: isStory ? 5 : 4)
        }
        .padding(isStory ? 10 : 8)
        .frame(width: isStory ? 236 : 196)
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), cornerRadius: 12, shadowOffset: 3)
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

    /// 全国の都道府県は日本地図なので、全国のカードと同じく細い縁取りにする。
    private var outlineWidth: CGFloat { content.kind == .nationwidePrefecture ? 0.4 : 0.6 }

    private var placeholderSystemImage: String { content.kind == .designatedCity ? "building.columns.fill" : "map.fill" }

    /// 「日本の中の位置」を選んだときだけ、見出しの右に添える日本地図の中のその県。
    @ViewBuilder
    private func locator(side: CGFloat, style: ShareCardBoxStyle) -> some View {
        if let shape = model.boxShape {
            ShareCardBoxShape(shape: shape, boxStyle: style, side: side)
        }
    }

    private func caption(_ text: String, style: ShareCardBoxStyle) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(style.secondary())
    }

    private func percentage(size: CGFloat, style: ShareCardBoxStyle) -> some View {
        Text(content.percentageText)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(style.primary())
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// 「30 / 54 市区町村」。単位は都道府県なら市区町村、政令指定都市なら区。
    private func count(size: CGFloat, style: ShareCardBoxStyle) -> some View {
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
