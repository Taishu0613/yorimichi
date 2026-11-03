import SwiftUI

/// 図鑑の「めざす／集めた」。最初は「めざす」にして、すでに集めたものを眺めるより次の行き先が見つかるようにする。
enum BadgeCollectionTab: CaseIterable, Identifiable {
    /// まだ次の目標があるバッジ(未獲得・段階式の途中)。
    case aiming
    /// 獲得済みのバッジ(段階式は1つ目のランク以上)。
    case collected

    var id: Self { self }

    var title: String {
        switch self {
        case .aiming: "めざす"
        case .collected: "集めた"
        }
    }
}

/// バッジ図鑑。旅の記録の入口カード(`BadgeEntryCard`)から開く。
/// 上から、集めた数 → 次のよりみち(おすすめ最大3件) → めざす／集めた → カテゴリ → スタンプ帳(固定順の3列)。
/// バッジの状態は持ち主(`MapScreen`)の`BadgeStore`をenvironmentで受け取る。プレビューなど渡されない場所では読み込み中の見た目になる。
struct BadgeCollectionView: View {
    @Environment(BadgeStore.self) private var badgeStore: BadgeStore?
    @Environment(\.badgeCurrentPrefectureCode) private var currentPrefectureCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var tab: BadgeCollectionTab = .aiming
    /// 絞り込み中のカテゴリ。nilは「すべて」。
    @State private var category: BadgeCategory?

    private var statuses: [BadgeStatus] { badgeStore?.statuses ?? [] }

    /// 基本は3列。文字を大きくしている時は名前が切れないよう2列にする。
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    /// バッジが1つ以上あるカテゴリだけを絞り込みの候補にする。
    private var availableCategories: [BadgeCategory] {
        BadgeCategory.allCases.filter { category in BadgeCatalog.all.contains { $0.category == category } }
    }

    private var visibleStatuses: [BadgeStatus] {
        statuses.filter { status in
            let matchesTab = switch tab {
            case .aiming: !status.isComplete
            case .collected: status.isEarned
            }
            return matchesTab && (category == nil || status.definition.category == category)
        }
    }

    var body: some View {
        // 市区町村の一覧と同じPOPなカードを並べるため、ListではなくScrollViewにする。
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                summary

                let recommendations = statuses.recommendations(currentPrefectureCode: currentPrefectureCode)
                if !recommendations.isEmpty {
                    PopSectionHeader(title: "次のよりみち")
                    recommendationCards(recommendations)
                }

                Picker("表示", selection: $tab) {
                    ForEach(BadgeCollectionTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)

                categoryChips

                grid

                PopFootnote("数え方は旅の記録と同じです。政令指定都市は区ごと、東京23区はそれぞれ1つとして数えます。")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Pop.paper.ignoresSafeArea())
        .navigationTitle("バッジ図鑑")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 集めた数

    private var summary: some View {
        let earned = statuses.earnedCount
        let total = BadgeCatalog.all.count
        return VStack(alignment: .leading, spacing: 10) {
            MarkerHeading("あなたの旅のコレクション")
            Text("旅の途中で、まだ知らない街に出会おう")
                .font(.subheadline)
                .foregroundStyle(Pop.muted)
            // 段階式のランクの数ではなく、獲得した種類の数を出す。
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(earned)個")
                    .font(.system(.title, design: .rounded, weight: .black))
                    .foregroundStyle(Pop.ink)
                Text("獲得 / 全\(total)個")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.muted)
            }
            .monospacedDigit()
            .accessibilityElement(children: .combine)
            PopProgressBar(fraction: Double(earned) / Double(total), fill: Pop.yellow)
                .accessibilityLabel("集めたバッジ")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 次のよりみち

    @ViewBuilder
    private func recommendationCards(_ recommendations: [BadgeStatus]) -> some View {
        if let first = recommendations.first {
            featuredCard(first)
        }
        let rest = Array(recommendations.dropFirst())
        if !rest.isEmpty {
            // 2件目以降は小さく並べる。文字を大きくしている時は縦に並べて切れないようにする。
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                ForEach(rest) { status in
                    compactCard(status)
                }
            }
        }
    }

    private func featuredCard(_ status: BadgeStatus) -> some View {
        PopNavigationCard(shadow: Pop.yellow.opacity(0.6)) {
            BadgeDetailView(badgeID: status.id)
        } label: {
            HStack(spacing: 14) {
                BadgeStampView(
                    definition: status.definition,
                    earnedTierCount: status.earnedTierCount,
                    progressFraction: status.fractionToNext,
                    size: 68
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(status.definition.name)
                            .font(.headline.weight(.heavy))
                        Spacer()
                        if let progressText = status.progressText {
                            Text(progressText)
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(Pop.ink)
                    Text(status.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Pop.ink)
                    PopProgressBar(fraction: status.fractionToNext)
                        .accessibilityLabel("進み具合")
                    Text("挑戦する")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Pop.theme)
                }
            }
        }
    }

    private func compactCard(_ status: BadgeStatus) -> some View {
        NavigationLink {
            BadgeDetailView(badgeID: status.id)
        } label: {
            HStack(spacing: 10) {
                BadgeStampView(
                    definition: status.definition,
                    earnedTierCount: status.earnedTierCount,
                    progressFraction: status.fractionToNext,
                    size: 44
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.definition.name)
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(Pop.ink)
                        .lineLimit(2)
                    if let progressText = status.progressText {
                        Text(progressText)
                            .font(.caption2)
                            .foregroundStyle(Pop.muted)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .popCard(shadowOffset: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - めざす／集めた・カテゴリ

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "すべて", isSelected: category == nil) { category = nil }
                ForEach(availableCategories) { candidate in
                    chip(title: candidate.name, isSelected: category == candidate) { category = candidate }
                }
            }
            .padding(.vertical, 2)
        }
        // チップの横スクロールが画面の左右の余白で切れて見えないよう、外側の余白まで広げる。
        .padding(.horizontal, -20)
        .contentMargins(.horizontal, 20, for: .scrollContent)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .heavy : .semibold))
                .foregroundStyle(isSelected ? Pop.inkOnAccent : Pop.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Pop.themeSoft : Pop.card, in: Capsule())
                .overlay(Capsule().stroke(isSelected ? Pop.theme : Pop.border, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var grid: some View {
        if statuses.isEmpty {
            // 訪問記録の評価を待つ間も同じ枠を並べ、評価後にレイアウトが跳ねないようにする。
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(BadgeCatalog.all) { definition in
                    BadgeGridCell(definition: definition, status: nil)
                }
            }
        } else if visibleStatuses.isEmpty {
            emptyMessage
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(visibleStatuses) { status in
                    NavigationLink {
                        BadgeDetailView(badgeID: status.id)
                    } label: {
                        BadgeGridCell(definition: status.definition, status: status, showsAchievedDate: tab == .collected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyMessage: some View {
        let text = switch tab {
        case .aiming: "このカテゴリのバッジはすべて集めました！"
        case .collected: "まだ集めたバッジはありません。「めざす」から次の行き先を探してみよう。"
        }
        return Label(text, systemImage: tab == .aiming ? "checkmark.seal" : "sparkles")
            .font(.subheadline)
            .foregroundStyle(Pop.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}

/// スタンプ帳の1枚。スタンプが主役で、名前と状態の一言を下に添える。
private struct BadgeGridCell: View {
    let definition: BadgeDefinition
    /// nilなら評価待ち(読み込み中)。
    let status: BadgeStatus?
    /// 「集めた」では、状態の代わりに獲得日を出して思い出を振り返れるようにする。
    var showsAchievedDate = false

    var body: some View {
        VStack(spacing: 6) {
            BadgeStampView(
                definition: definition,
                earnedTierCount: status?.earnedTierCount ?? 0,
                progressFraction: status?.fractionToNext ?? 0,
                size: 84
            )
            Text(definition.name)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(Pop.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            statusLabel
            if showsAchievedDate, let status {
                Text(status.achievedDateShortText)
                    .font(.caption2)
                    .foregroundStyle(Pop.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(definition.name)
        .accessibilityValue(status?.accessibilityStatus ?? "読み込み中")
        .accessibilityAddTraits(status == nil ? [] : .isButton)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if let status {
            if status.isEarned {
                Text(status.shortStatusText)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Pop.inkOnAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    // 差し色はモードによらず明るい色にして、上の文字を常に濃い色で読めるようにする(PopPillと同じ考え方)。
                    .background(status.rank?.ringColor.mix(with: .white, by: 0.5) ?? Pop.yellow, in: Capsule())
            } else {
                Text(status.shortStatusText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Pop.muted)
                    .monospacedDigit()
            }
        } else {
            Text("読み込み中")
                .font(.caption2)
                .redacted(reason: .placeholder)
        }
    }
}

/// 旅の記録に置く、バッジ図鑑への入口。獲得数と、集めたスタンプの並び、もうすぐ届く目標をひとまとめにする。
/// 旅の記録の本来の一覧を押し下げすぎないよう、高さは数行に抑える。
struct BadgeEntryCard: View {
    @Environment(BadgeStore.self) private var badgeStore: BadgeStore?
    @Environment(\.badgeCurrentPrefectureCode) private var currentPrefectureCode

    var body: some View {
        let statuses = badgeStore?.statuses ?? []
        PopNavigationCard(shadow: Pop.yellow.opacity(0.6)) {
            BadgeCollectionView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    PopIconBadge(systemImage: "rosette", fill: Pop.yellow, size: 30)
                    Text("バッジ図鑑")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Pop.ink)
                    Spacer()
                    Text("\(statuses.earnedCount) / \(BadgeCatalog.all.count) こ獲得")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Pop.ink)
                        .monospacedDigit()
                }
                // 集めたスタンプは塗り、まだのものは枠だけにして、コレクションの埋まり具合を見せる。
                HStack(spacing: 4) {
                    ForEach(BadgeCatalog.all) { definition in
                        let isEarned = statuses.first { $0.id == definition.id }?.isEarned == true
                        Circle()
                            .fill(isEarned ? definition.artwork.primary : Color.clear)
                            .overlay(Circle().stroke(isEarned ? definition.artwork.primary : Pop.muted.opacity(0.5), lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)
                Text(message(statuses))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.ink)
                    .redacted(reason: statuses.isEmpty ? .placeholder : [])
            }
        }
    }

    private func message(_ statuses: [BadgeStatus]) -> String {
        guard !statuses.isEmpty else { return "バッジの進み具合を確かめています" }
        if statuses.earnedCount == 0 {
            return "最初のバッジを見つけよう"
        }
        if let recent = statuses.recentlyEarned() {
            return "最近獲得：「\(recent.definition.name)」"
        }
        return statuses.recommendations(currentPrefectureCode: currentPrefectureCode, limit: 1).first?.nearGoalText
            ?? "すべてのバッジを集めました！"
    }
}

#Preview {
    NavigationStack {
        BadgeCollectionView()
    }
}
