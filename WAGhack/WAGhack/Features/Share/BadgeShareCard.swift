import SwiftUI

/// バッジのシェア用カードに載せるもの。バッジの絵・名前・ひとこと、取った日(記録があれば)。
///
/// 地図のカードと同じく、どこで取ったか(ピン・座標・住所・訪問日時)は載せない。日付は「獲得した日」だけで、時刻は持たない。
struct BadgeShareCardContent {
    let definition: BadgeDefinition
    let earnedTierCount: Int
    /// 段階式のバッジで獲得したランクの名前(「ゴールド」など)。段階の無いバッジはnil。
    let rankName: String?
    /// 「2026年11月27日に獲得」。記録が無い(バッジ機能の導入前に満たした)ときはnil。
    let achievedDateText: String?

    init(status: BadgeStatus, calendar: Calendar = .current) {
        definition = status.definition
        earnedTierCount = status.earnedTierCount
        rankName = status.rank?.name
        // 詳細画面と同じく、段階式は今のランクに上がった日、それ以外は獲得した日。
        let date = status.definition.isTiered ? status.achievement?.tierAchievedAt : status.achievement?.achievedAt
        achievedDateText = date.map { date in
            let suffix = status.rank.map { "\($0.name)に到達" } ?? "獲得"
            return "\(ShareCardContent.dateText(for: date, calendar: calendar))に\(suffix)"
        }
    }

    var name: String { definition.name }

    /// 画像と一緒に共有する文。
    var shareText: String {
        Self.shareText(badgeName: definition.name)
    }

    static func shareText(badgeName: String) -> String {
        "バッジ「\(badgeName)」を獲得しました #よりみち\n\(ShareCardContent.appStoreURL.absoluteString)"
    }
}

/// バッジのシェア用カード。スタンプを台紙に押したように大きく描き、名前とひとことを添える。
struct BadgeShareCardView: View {
    let content: BadgeShareCardContent
    let layout: ShareCardLayout

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

    /// ストーリーズの上下に重なるアプリの表示を避けて、中身を真ん中に寄せる(地図のカードと同じ)。
    private var storyLayout: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                MarkerHeading("バッジ獲得！", size: 28)
                if let achievedDateText = content.achievedDateText {
                    ShareCardCaption(text: achievedDateText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            stampBoard(size: 200)
            VStack(spacing: 10) {
                MarkerHeading(content.name, size: 30)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(content.definition.summary)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Pop.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                pills
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .popCard(shadow: Pop.yellow.opacity(0.8), shadowOffset: 5)
            ShareCardAppMark(logoSize: 30)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MarkerHeading("バッジ獲得！", size: 22)
                Spacer(minLength: 8)
                if let achievedDateText = content.achievedDateText {
                    ShareCardCaption(text: achievedDateText, size: 11)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                stampBoard(size: 130)
                VStack(alignment: .leading, spacing: 8) {
                    Text(content.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Pop.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(content.definition.summary)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Pop.muted)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 右の列は細く、分類とランクを並べると切れるので、スタンプの下に横幅いっぱいで並べる。
            pills
            Spacer(minLength: 0)
            ShareCardAppMark(logoSize: 26)
        }
        .padding(20)
    }

    /// 詳細画面の見出しと同じ、点線の台紙に押したスタンプ。
    private func stampBoard(size: CGFloat) -> some View {
        BadgeStampView(definition: content.definition, earnedTierCount: content.earnedTierCount, size: size)
            .padding(size * 0.12)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Pop.themeTint.opacity(0.55))
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Pop.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
            }
    }

    private var pills: some View {
        HStack(spacing: 6) {
            PopPill(text: content.definition.category.name, systemImage: "tag.fill", fill: Pop.themeSoft)
            if let rankName = content.rankName {
                PopPill(text: rankName, systemImage: "star.fill", fill: Pop.yellow)
            }
        }
        .lineLimit(1)
    }
}

/// バッジをシェアする画面。バッジの詳細と、バッジ獲得の知らせから開く。
struct BadgeShareSheet: View {
    let status: BadgeStatus

    @State private var layout: ShareCardLayout = .story
    @State private var rendered: RenderedShareCard?

    var body: some View {
        ShareCardSheetScaffold(
            navigationTitle: "バッジをシェア",
            footnote: "画像にはバッジと獲得した日だけが入ります。訪れた場所や時刻は入りません。",
            rendered: rendered,
            layout: $layout
        ) {
            EmptyView()
        }
        .task(id: layout) {
            let content = BadgeShareCardContent(status: status)
            rendered = ShareCardRenderer.render(BadgeShareCardView(content: content, layout: layout), layout: layout)
                .map { RenderedShareCard(image: $0, message: content.shareText, title: "バッジ「\(content.name)」") }
        }
    }
}
