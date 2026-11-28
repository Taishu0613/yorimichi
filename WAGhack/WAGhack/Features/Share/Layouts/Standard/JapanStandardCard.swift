import SwiftUI
import UIKit

/// SNSでシェアする画像の中身。`ShareCardRenderer`が`size.pointSize`の大きさで組み、3倍で書き出す。
///
/// 画像として書き出すので、端末の設定に左右されないようにしている。
/// - 色: 常にライトモード(`ShareCardRenderer`で固定)。ダークモードの人が作っても同じ白いカードになる。
/// - 文字: Dynamic Typeを`.large`に固定。文字を大きくしている人の画像だけ枠からはみ出さないようにする。
/// 載せるのは塗った地図と件数だけ。ピン・座標・住所・訪問日時は載せない(`ShareCardContent`参照)。
struct JapanStandardCard: View {
    let content: ShareCardContent
    let size: ShareCardSize
    let fill: ShareCardFill
    let maps: ShareCardMaps
    /// 地図の下に薄く敷く本物の地図。撮れるまで・撮れなかったときはnilで、図形だけの地図にする。写真があるときは使わない。
    var backdrop: ShareMapBackdrop? = nil
    /// カードいっぱいに敷く写真(1.8.0 (5))。あれば塗った地図を写真の上に描き、件数の箱を`boxPosition`に置く。
    var photo: UIImage? = nil
    var boxStyle: ShareCardBoxStyle = .app
    /// 写真を敷いたときの箱の位置。写真が無いときは使わない(並びが決まっているため)。
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
            appMark(logoSize: 30)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    /// 写真ありの縦長。見出しと件数を1つの箱にまとめて上・真ん中・下に置き、残りの広さに地図を描く。
    /// ストーリーズの上下に重なるアプリの表示(上約60pt・下約83pt)には文字を掛けない(豆知識の写真のカードと同じ余白)。
    private var storyPhotoLayout: some View {
        VStack(spacing: 12) {
            ShareCardBoxArrangement(position: boxPosition) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        boxHeading(size: 26)
                        dateLabel(size: 13, style: boxStyle)
                    }
                    municipalityCount(countSize: 36)
                    PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) { statChips(fontSize: 13) }
                        VStack(alignment: .leading, spacing: 6) { statChips(fontSize: 13) }
                    }
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: 4)
            } filler: {
                photoMap
            }
            appMark(logoSize: 30, isOverPhoto: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 96)
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
            appMark(logoSize: 26)
        }
        .padding(20)
    }

    private var squarePhotoLayout: some View {
        VStack(spacing: 8) {
            ShareCardBoxArrangement(position: boxPosition, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        boxHeading(size: 20)
                        Spacer(minLength: 8)
                        dateLabel(size: 11, style: boxStyle)
                    }
                    municipalityCount(countSize: 28)
                    PopProgressBar(fraction: content.fraction, fill: boxStyle.progressFill, track: boxStyle.progressTrack)
                    PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: 3)
            } filler: {
                photoMap
            }
            appMark(logoSize: 22, isOverPhoto: true)
        }
        .padding(18)
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

    private func appMark(logoSize: CGFloat, isOverPhoto: Bool = false) -> some View {
        ShareCardAppMark(logoSize: logoSize, isOverPhoto: isOverPhoto)
    }
}
