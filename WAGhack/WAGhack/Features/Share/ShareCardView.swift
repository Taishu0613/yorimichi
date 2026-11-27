import SwiftUI

/// SNSでシェアする画像の中身。`ShareCardRenderer`が`layout.pointSize`の大きさで組み、3倍で書き出す。
///
/// 画像として書き出すので、端末の設定に左右されないようにしている。
/// - 色: 常にライトモード(`ShareCardRenderer`で固定)。ダークモードの人が作っても同じ白いカードになる。
/// - 文字: Dynamic Typeを`.large`に固定。文字を大きくしている人の画像だけ枠からはみ出さないようにする。
/// 載せるのは塗った地図と件数だけ。ピン・座標・住所・訪問日時は載せない(`ShareCardContent`参照)。
struct ShareCardView: View {
    let content: ShareCardContent
    let layout: ShareCardLayout
    let fill: ShareCardFill
    let maps: ShareCardMaps

    var body: some View {
        Group {
            switch layout {
            case .story: storyLayout
            case .square: squareLayout
            }
        }
        .frame(width: layout.pointSize.width, height: layout.pointSize.height)
        .background(background)
    }

    // MARK: - 縦長

    /// ストーリーズは上下(各約250px)にアプリの表示が重なるので、上下に余白を多めに取って中身を真ん中に寄せる。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                MarkerHeading("わたしの日本地図", size: 28)
                dateLabel(size: 13)
            }
            map
                .padding(12)
                .frame(maxWidth: .infinity)
                .frame(height: 290)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            VStack(alignment: .leading, spacing: 10) {
                municipalityCount(countSize: 40)
                PopProgressBar(fraction: content.fraction)
                HStack(spacing: 14) {
                    statChips(fontSize: 14)
                }
                PopPill(text: content.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .popCard(shadow: Pop.yellow.opacity(0.8), shadowOffset: 5)
            appMark(logoSize: 30)
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
                dateLabel(size: 11)
            }
            HStack(alignment: .top, spacing: 12) {
                map
                    .padding(8)
                    .frame(width: 176, height: 236)
                    .popCard(shadow: Pop.theme.opacity(0.35))
                VStack(alignment: .leading, spacing: 8) {
                    compactMunicipalityCount
                    PopProgressBar(fraction: content.fraction)
                    VStack(alignment: .leading, spacing: 6) {
                        statChips(fontSize: 12)
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

    // MARK: - 部品

    /// 薄いテーマ色の地に、水玉を散らしてPOPに見せる。
    private var background: some View {
        Pop.themeSoft
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 22
                    var row = 0
                    var y: CGFloat = 0
                    while y < size.height + spacing {
                        var x: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                        while x < size.width + spacing {
                            context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.8)))
                            x += spacing
                        }
                        y += spacing * 0.87
                        row += 1
                    }
                }
            }
    }

    private func dateLabel(size: CGFloat) -> some View {
        Text(content.dateText)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Pop.muted)
            .lineLimit(1)
            .fixedSize()
    }

    private var map: some View {
        let silhouette = switch fill {
        case .municipalities: maps.municipalityMap
        case .prefectures: maps.prefectureMap
        }
        // 書き出すと3倍になるので、区画の隙間を埋める縁取りは0.4pt(1.2px)で足りる。太いと小さな町村が膨らんで見える。
        return SilhouetteMapView(map: silhouette, visitedCodes: content.visitedCodes(for: fill), outlineWidth: 0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func municipalityCount(countSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("訪れた市区町村")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Pop.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(content.visitedMunicipalityCount.formatted())
                    .font(.system(size: countSize, weight: .black, design: .rounded))
                Text("/ \(content.totalMunicipalityCount.formatted())")
                    .font(.system(size: countSize * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(Pop.muted)
                Spacer(minLength: 4)
                Text(content.percentageText)
                    .font(.system(size: countSize * 0.55, weight: .black, design: .rounded))
            }
            .foregroundStyle(Pop.ink)
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
    private func statChips(fontSize: CGFloat) -> some View {
        statChip(
            systemImage: "map.fill", title: "都道府県",
            value: "\(content.visitedPrefectureCount) / \(content.totalPrefectureCount)", fontSize: fontSize
        )
        if content.completedPrefectureCount > 0 {
            statChip(
                systemImage: "crown.fill", title: "完全踏破",
                value: "\(content.completedPrefectureCount)都道府県", fontSize: fontSize
            )
        }
    }

    /// `fontSize`は形ごとに決める。正方形の右の細い列(約130pt)では、「完全踏破 1都道府県」が1行に収まる12pt。
    private func statChip(systemImage: String, title: String, value: String, fontSize: CGFloat) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(Pop.theme)
            Text(title)
                .foregroundStyle(Pop.muted)
            Text(value)
                .foregroundStyle(Pop.ink)
                .monospacedDigit()
        }
        .font(.system(size: fontSize, weight: .heavy, design: .rounded))
        .lineLimit(1)
    }

    /// 右下に添えるアプリの印。
    private func appMark(logoSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
            Text("よりみち")
                .font(.system(size: logoSize * 0.55, weight: .black, design: .rounded))
                .foregroundStyle(Pop.ink)
        }
    }
}
