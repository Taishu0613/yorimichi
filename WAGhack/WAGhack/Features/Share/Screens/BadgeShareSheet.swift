import SwiftUI

/// バッジのシェア用カードに載せるもの。バッジの絵・名前・ひとこと・入手条件、取った日(記録があれば)。
///
/// 入手条件を載せるのは、バッジを自慢したくてシェアする人が「何をして取ったか」を伝えられるようにするため。
/// アプリには条件を伏せたバッジが無く(詳細画面で全バッジの達成条件を見せている)、シェアできるのは獲得済みだけなので、
/// 伏せる扱いは要らない。条件を伏せるバッジを足すときは、ここで獲得前に見せないようにすること。
///
/// 地図のカードと同じく、どこで取ったか(ピン・座標・住所・訪問日時)は載せない。日付は「獲得した日」だけで、時刻は持たない。
struct BadgeShareCardContent {
    let definition: BadgeDefinition
    let earnedTierCount: Int
    /// 段階式のバッジで獲得したランクの名前(「ゴールド」など)。段階の無いバッジはnil。
    let rankName: String?
    /// 「2026年11月27日に獲得」。記録が無い(バッジ機能の導入前に満たした)ときはnil。
    let achievedDateText: String?
    /// 入手条件(「市区町村を100か所訪れる」など)。
    let conditionText: String

    init(status: BadgeStatus, calendar: Calendar = .current) {
        definition = status.definition
        earnedTierCount = status.earnedTierCount
        rankName = status.rank?.name
        conditionText = Self.conditionText(definition: status.definition, earnedTierCount: status.earnedTierCount)
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
        Self.shareText(badgeName: definition.name, condition: conditionText)
    }

    static func shareText(badgeName: String, condition: String) -> String {
        "バッジ「\(badgeName)」を獲得しました(\(condition)) #よりみち\n\(ShareCardContent.appStoreURL.absoluteString)"
    }

    /// 入手条件の文。詳細画面の「達成条件」と同じ`BadgeDefinition.conditionText`から作る。
    ///
    /// - 段階式は獲得したランクの閾値の条件にする(ゴールドなら、ゴールドに上がった条件)。未獲得なら最初の段階。
    /// - 詳細画面の条件には「それぞれの区のどこかを記録すれば…」のような補足が続くことがあるので、
    ///   カードと共有文には最初の一文(「。」まで)だけを使う。
    static func conditionText(definition: BadgeDefinition, earnedTierCount: Int) -> String {
        guard !definition.tiers.isEmpty else { return "" }
        let tierIndex = min(max(earnedTierCount, 1), definition.tiers.count) - 1
        let full = definition.conditionText(definition.tiers[tierIndex])
        let firstSentence = full.split(separator: "。", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? full
        return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// バッジのシェア用カード。スタンプを台紙に押したように大きく描き、名前とひとことを添える。
struct BadgeShareCardView: View {
    let content: BadgeShareCardContent
    let size: ShareCardSize

    var body: some View {
        Group {
            switch size {
            case .story: storyLayout
            case .square: squareLayout
            }
        }
        .frame(width: size.pointSize.width, height: size.pointSize.height)
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
            stampBoard(size: 150)
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
                conditionBox(fontSize: 15)
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
                    // 正方形は狭いので、ひとこと(summary)より自慢の中身になる入手条件を優先して載せる。
                    conditionBox(fontSize: 12.5, fill: Color.white)
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

    /// 入手条件。「入手条件」の見出しを付けて、ひとことと見分けられるようにする。
    /// 縦長は白いカードの中なので薄い水色、正方形はカードの地(水色)の上なので白で囲む。
    private func conditionBox(fontSize: CGFloat, fill: Color = Pop.themeTint) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("入手条件", systemImage: "flag.checkered")
                .font(.system(size: fontSize * 0.8, weight: .heavy))
                .foregroundStyle(Pop.muted)
            Text(content.conditionText)
                .font(.system(size: fontSize, weight: .heavy))
                .foregroundStyle(Pop.ink)
                .lineSpacing(3)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, fontSize * 0.8)
        .padding(.vertical, fontSize * 0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    @State private var size: ShareCardSize = .story
    @State private var rendered: RenderedShareCard?

    var body: some View {
        ShareCardSheetScaffold(
            navigationTitle: "バッジをシェア",
            footnote: "画像にはバッジと入手条件、獲得した日だけが入ります。訪れた場所や時刻は入りません。",
            rendered: rendered,
            size: $size
        ) {
            EmptyView()
        }
        .task(id: size) {
            let content = BadgeShareCardContent(status: status)
            rendered = ShareCardRenderer.render(BadgeShareCardView(content: content, size: size), size: size)
                .map { RenderedShareCard(image: $0, message: content.shareText, title: "バッジ「\(content.name)」") }
        }
    }
}
