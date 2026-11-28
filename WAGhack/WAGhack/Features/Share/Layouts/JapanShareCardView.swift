import SwiftUI
import UIKit

/// 全国のシェア用カード(1.8.0 (6)の見た目)。`ShareCardCanvas`から描く。
///
/// 載せるのは塗った地図と件数だけ。ピン・座標・住所・訪問日時は載せない(`ShareCardContent`参照)。
/// - 写真なし: 水玉の地に、本物の地図を薄く敷いた日本地図の枠と、件数の箱。
/// - 写真あり: 写真をカードいっぱいに(暗くせず)敷き、上に塗った日本地図を大きく、その下に見出しと件数の箱(標準・小さい箱、1.8.0 (10))。
struct JapanShareCardView: View {
    let content: ShareCardContent
    let fill: ShareCardFill
    let maps: ShareCardMaps
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

    /// ストーリーズは上下(各約250px)にアプリの表示が重なるので、上下に余白を多めに取って中身を真ん中に寄せる。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                MarkerHeading("わたしの日本地図", size: 28)
                dateLabel(size: 13, style: .app)
            }
            map(box: .japanStory)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            VStack(alignment: .leading, spacing: 10) {
                municipalityCount(countSize: 40)
                PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
                // 2つの数が横に収まらないとき(完全踏破が出る時)は、「完全…」と切れないよう2行にする。
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        statChips(fontSize: 14)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        statChips(fontSize: 14)
                    }
                }
                PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .shareCardBox(boxStyle, shadow: Pop.yellow.opacity(0.8), shadowOffset: 5)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    // MARK: - 正方形

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                MarkerHeading("わたしの日本地図", size: 22)
                Spacer(minLength: 8)
                dateLabel(size: 11, style: .app)
            }
            HStack(alignment: .top, spacing: 12) {
                map(box: .japanSquare)
                    .popCard(shadow: Pop.theme.opacity(0.35))
                // 正方形の右の列は箱に入れていないので、線の版でもアプリの色で描く(水玉の地に白い字は読めないため)。
                VStack(alignment: .leading, spacing: 8) {
                    compactMunicipalityCount
                    PopProgressBar(fraction: content.fraction)
                    VStack(alignment: .leading, spacing: 6) {
                        statChips(fontSize: 12, style: .app)
                    }
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
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

    /// 上に塗った日本地図を大きく、その下に見出しと件数の箱。
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
            HStack(alignment: .firstTextBaseline) {
                boxHeading(size: isStory ? 22 : 18)
                Spacer(minLength: 8)
                dateLabel(size: isStory ? 12 : 10, style: boxStyle)
            }
            municipalityCount(countSize: isStory ? 32 : 24)
            PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
            if isStory {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { statChips(fontSize: 12) }
                    VStack(alignment: .leading, spacing: 4) { statChips(fontSize: 12) }
                }
            }
            PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
        }
        .padding(isStory ? 12 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: isStory ? 4 : 3)
    }

    /// 小さい箱: 見出しと日付を1行に、大きな数の右に「/ 全体」と割合を縦に添え、細い棒と都道府県の数を小さく1行。
    /// 達成の札は載せない(都道府県の制覇率のカードと同じく「そこはいらない」との声)。
    private var compactBox: some View {
        VStack(alignment: .leading, spacing: isStory ? 4 : 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                boxHeading(size: isStory ? 16 : 14)
                Spacer(minLength: 6)
                dateLabel(size: isStory ? 10 : 9, style: boxStyle)
            }
            HStack(alignment: .center, spacing: 8) {
                Text(content.visitedMunicipalityCount.formatted())
                    .font(.system(size: isStory ? 34 : 26, weight: .black, design: .rounded))
                    .foregroundStyle(boxStyle.primary())
                VStack(alignment: .leading, spacing: 0) {
                    Text("/ \(content.totalMunicipalityCount.formatted()) 市区町村")
                        .font(.system(size: isStory ? 10 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(boxStyle.secondary())
                    Text(content.percentageText)
                        .font(.system(size: isStory ? 16 : 13, weight: .black, design: .rounded))
                        .foregroundStyle(boxStyle.primary())
                }
                Spacer(minLength: 0)
            }
            .monospacedDigit()
            .lineLimit(1)
            ShareCardThinProgressBar(fraction: content.fraction, style: boxStyle, height: isStory ? 5 : 4)
            HStack(spacing: 10) {
                statChips(fontSize: isStory ? 10 : 9)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(isStory ? 10 : 8)
        .frame(width: isStory ? 236 : 196)
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), cornerRadius: 12, shadowOffset: 3)
    }

    // MARK: - 部品

    private func boxHeading(size: CGFloat) -> some View {
        MarkerHeading("わたしの日本地図", size: size, marker: boxStyle.marker(), foreground: boxStyle.primary())
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

    private var silhouette: SilhouetteMap {
        switch fill {
        case .municipalities: maps.municipalityMap
        case .prefectures: maps.prefectureMap
        }
    }

    /// 塗った日本地図。2種類の地図(`ShareCardMaps`)は同じ枠で作ってあるので、本物の地図はどちらにも同じものを敷ける。
    private func map(box: ShareCardMapBox) -> some View {
        // 書き出すと3倍になるので、区画の隙間を埋める縁取りは0.4pt(1.2px)で足りる。太いと小さな町村が膨らんで見える。
        ShareMapCanvas(
            map: silhouette, visitedCodes: content.visitedCodes(for: fill), box: box, backdrop: backdrop, outlineWidth: 0.4
        )
    }

    /// 写真の上に描く地図。未訪問は線だけにして写真を透かす。
    private var photoMap: some View {
        ShareCardPhotoMap(map: silhouette, visitedCodes: content.visitedCodes(for: fill), outlineWidth: 0.4)
    }

    private func municipalityCount(countSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("訪れた市区町村")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(boxStyle.secondary())
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(content.visitedMunicipalityCount.formatted())
                    .font(.system(size: countSize, weight: .black, design: .rounded))
                Text("/ \(content.totalMunicipalityCount.formatted())")
                    .font(.system(size: countSize * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(boxStyle.secondary())
                Spacer(minLength: 4)
                Text(content.percentageText)
                    .font(.system(size: countSize * 0.55, weight: .black, design: .rounded))
            }
            .foregroundStyle(boxStyle.primary())
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    /// 正方形の右の細い列(約130pt)用。1行に並べると4桁の数で切れるため、数と割合を2行に分ける。
    private var compactMunicipalityCount: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("訪れた市区町村")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Pop.muted)
            Text(content.visitedMunicipalityCount.formatted())
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Pop.ink)
            Text("/ \(content.totalMunicipalityCount.formatted())　\(content.percentageText)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Pop.muted)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// 都道府県の数と、完全踏破した都道府県の数。完全踏破が0件なら「0」を見せず省く。
    @ViewBuilder
    private func statChips(fontSize: CGFloat, style: ShareCardBoxStyle? = nil) -> some View {
        let style = style ?? boxStyle
        statChip(
            systemImage: "map.fill", title: "都道府県",
            value: "\(content.visitedPrefectureCount) / \(content.totalPrefectureCount)", fontSize: fontSize, style: style
        )
        if content.completedPrefectureCount > 0 {
            statChip(
                systemImage: "crown.fill", title: "完全踏破",
                value: "\(content.completedPrefectureCount)都道府県", fontSize: fontSize, style: style
            )
        }
    }

    /// `fontSize`は形ごとに決める。正方形の右の細い列(約130pt)では、「完全踏破 1都道府県」が1行に収まる12pt。
    private func statChip(systemImage: String, title: String, value: String, fontSize: CGFloat, style: ShareCardBoxStyle) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(style.primary(Pop.theme))
            Text(title)
                .foregroundStyle(style.secondary())
            Text(value)
                .foregroundStyle(style.primary())
                .monospacedDigit()
        }
        .font(.system(size: fontSize, weight: .heavy, design: .rounded))
        .lineLimit(1)
    }
}
