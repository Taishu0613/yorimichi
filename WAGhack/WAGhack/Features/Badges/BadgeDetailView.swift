import SwiftUI

extension EnvironmentValues {
    /// 「地図で探す」の処理。旅の記録のシートを閉じて地図を寄せる。地図の無い場所(プレビュー)ではnilでボタンを出さない。
    @Entry var showBadgeAreaOnMap: ((BadgeMapFocus) -> Void)? = nil
}

/// バッジ1種類の詳細。「何を達成したか」「あと何をすればよいか」を上から順に伝える。
/// 状態は`BadgeStore`から毎回引くので、開いている間に訪問が増えてもそのまま反映される。
struct BadgeDetailView: View {
    let badgeID: BadgeID

    @Environment(BadgeStore.self) private var badgeStore: BadgeStore?
    @Environment(\.showBadgeAreaOnMap) private var showBadgeAreaOnMap
    /// 対象の街が多い時に、最初の数件だけ見せるか全部見せるか。
    @State private var showsAllTargets = false

    /// 対象の街を最初に見せる件数。
    private static let collapsedTargetCount = 8
    /// 対象のまとまり(ふたごのまちの組)を最初に見せる件数。
    private static let collapsedGroupCount = 4

    var body: some View {
        ScrollView {
            if let status = badgeStore?.status(for: badgeID) {
                VStack(alignment: .leading, spacing: 16) {
                    header(status)
                    statusCard(status)
                    conditionCard(status)
                    if !status.progress.checklist.isEmpty {
                        checklistCard(status)
                    }
                    if !status.progress.groups.isEmpty {
                        groupsCard(status)
                    }
                    if !status.progress.prefectureCounts.isEmpty {
                        prefectureCountsCard(status)
                    }
                    mapButton(status)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            }
        }
        .background(Pop.paper.ignoresSafeArea())
        .navigationTitle("バッジ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 見出し

    private func header(_ status: BadgeStatus) -> some View {
        VStack(spacing: 12) {
            BadgeStampView(
                definition: status.definition,
                earnedTierCount: status.earnedTierCount,
                progressFraction: status.fractionToNext,
                size: 150
            )
            .padding(18)
            // 獲得済みは台紙に押したように見せる。まだのものは台紙の枠だけを用意して、押す場所があることを伝える。
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(status.isEarned ? Pop.themeSoft.opacity(0.55) : Pop.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Pop.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
            }
            MarkerHeading(status.definition.name, size: 24)
            Text(status.definition.summary)
                .font(.subheadline)
                .foregroundStyle(Pop.muted)
            PopPill(text: status.definition.category, systemImage: "tag.fill", fill: Pop.themeSoft)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue(status.accessibilityStatus)
    }

    // MARK: - 今の状態

    private func statusCard(_ status: BadgeStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PopIconBadge(
                    systemImage: status.isComplete ? "checkmark.seal.fill" : (status.isAvailable ? "flag.fill" : "hourglass"),
                    fill: status.isComplete ? Pop.yellow : Pop.themeSoft,
                    size: 32
                )
                Text(status.headline)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
            }
            if let progressText = status.progressText {
                PopProgressBar(fraction: status.fractionToNext)
                    .accessibilityLabel("次の目標までの進み具合")
                Text(progressText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.muted)
                    .monospacedDigit()
            }
            if let note = note(for: status) {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(Pop.ink)
            }
            if let dateText = achievedDateText(status) {
                Label(dateText, systemImage: "calendar")
                    .font(.footnote)
                    .foregroundStyle(Pop.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard(shadow: status.isEarned ? Pop.yellow.opacity(0.7) : Pop.shadow)
    }

    private func note(for status: BadgeStatus) -> String? {
        guard status.isAvailable else {
            return "判定の準備ができるまで、今の記録では獲得になりません。アップデートをお楽しみに。"
        }
        if status.definition.id == .localExplorer, let top = status.progress.prefectureCounts.first {
            return "いちばん多いのは\(top.name)の\(top.visited)か所です"
        }
        return nil
    }

    private func achievedDateText(_ status: BadgeStatus) -> String? {
        guard status.isEarned else { return nil }
        // 段階式は今の最高ランクに上がった日を、それ以外は獲得した日を出す。
        let date = status.definition.isTiered ? status.achievement?.tierAchievedAt : status.achievement?.achievedAt
        let prefix = status.rank.map { "\($0.name)に到達" } ?? "獲得"
        guard let date else {
            // バッジ機能の導入前の訪問で獲得した分は、いつ条件を満たしたか分からない。
            return "これまでの旅で\(prefix)"
        }
        return "\(date.formatted(date: .long, time: .omitted))に\(prefix)"
    }

    // MARK: - 達成条件

    private func conditionCard(_ status: BadgeStatus) -> some View {
        let definition = status.definition
        return VStack(alignment: .leading, spacing: 12) {
            Text("達成条件")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            if definition.isTiered {
                // 段階ごとの閾値とランクを並べ、どの数字がどのランクか分かるようにする。
                ForEach(Array(definition.tiers.enumerated()), id: \.offset) { index, threshold in
                    let rank = BadgeRank(rawValue: index)
                    let isReached = index < status.earnedTierCount
                    HStack(spacing: 10) {
                        Image(systemName: isReached ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isReached ? Pop.theme : Pop.muted)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(rank?.name ?? "")
                                    .font(.subheadline.weight(.heavy))
                                Text(String(repeating: "★", count: index + 1))
                                    .font(.caption)
                                    .foregroundStyle(rank?.ringColor ?? Pop.muted)
                                    .accessibilityHidden(true)
                            }
                            Text(definition.conditionText(threshold))
                                .font(.subheadline)
                                .foregroundStyle(Pop.muted)
                        }
                        .foregroundStyle(Pop.ink)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(isReached ? "達成" : "未達成")
                }
            } else if let threshold = definition.tiers.first {
                Text(definition.conditionText(threshold))
                    .font(.subheadline)
                    .foregroundStyle(Pop.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
    }

    // MARK: - 対象の街

    private func checklistCard(_ status: BadgeStatus) -> some View {
        // 訪れた街を先に並べる。閉じた状態でも「あなたの歩いた街」が見え、続きに未訪問の街が来る。
        let items = status.progress.checklist.filter(\.isVisited) + status.progress.checklist.filter { !$0.isVisited }
        let visibleItems = showsAllTargets ? items : Array(items.prefix(Self.collapsedTargetCount))
        // 対象が複数の都道府県にまたがる時(数字の旅人)は、同じ名前の町と区別できるよう都道府県も添える。
        let showsPrefecture = Set(items.map(\.prefectureCode)).count > 1
        let columnCount = showsPrefecture ? 1 : 2
        return VStack(alignment: .leading, spacing: 12) {
            Text("あなたの歩いた街")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columnCount), spacing: 10) {
                ForEach(visibleItems) { item in
                    targetRow(item, showsPrefecture: showsPrefecture)
                }
            }
            if items.count > Self.collapsedTargetCount {
                expandButton(isExpanded: showsAllTargets, total: items.count) { showsAllTargets.toggle() }
            }
            if showBadgeAreaOnMap != nil, items.contains(where: { !$0.isVisited }) {
                PopFootnote("まだ訪れていない街を押すと、地図でその街を見られます。")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
    }

    /// 三都物語の都市、ふたごのまちの組ごとの訪問状況。
    private func groupsCard(_ status: BadgeStatus) -> some View {
        let groups = status.progress.groups
        let visibleGroups = showsAllTargets ? groups : Array(groups.prefix(Self.collapsedGroupCount))
        return VStack(alignment: .leading, spacing: 14) {
            Text(status.definition.id == .twinTowns ? "同じ名前のまち" : "めぐる都市")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            ForEach(visibleGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: group.isSatisfied ? "checkmark.seal.fill" : "seal")
                            .foregroundStyle(group.isSatisfied ? Pop.theme : Pop.muted)
                            .accessibilityHidden(true)
                        Text(group.name)
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Pop.ink)
                        Spacer()
                        if group.area != nil {
                            Text("\(group.visitedCount) / \(group.items.count)区")
                                .font(.caption)
                                .foregroundStyle(Pop.muted)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(group.isSatisfied ? "達成" : "未達成")
                    if let area = group.area {
                        // 都市は区が多いので区の一覧は出さず、まだの都市だけ地図へ向かえるようにする。
                        if !group.isSatisfied, let showBadgeAreaOnMap {
                            Button {
                                showBadgeAreaOnMap(.area(area))
                            } label: {
                                Label("地図で\(area.name)を見る", systemImage: "map")
                                    .font(.footnote.weight(.bold))
                            }
                            .tint(Pop.theme)
                        }
                    } else {
                        ForEach(group.items) { item in
                            targetRow(item, showsPrefecture: true)
                        }
                        .padding(.leading, 26)
                    }
                }
            }
            if groups.count > Self.collapsedGroupCount {
                expandButton(isExpanded: showsAllTargets, total: groups.count) { showsAllTargets.toggle() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
    }

    /// 対象の街の1行。まだ訪れていない街は、押すと地図でその街へ寄せる(地図の無いプレビューでは押せない)。
    @ViewBuilder
    private func targetRow(_ item: BadgeChecklistItem, showsPrefecture: Bool) -> some View {
        let label = Label {
            HStack(spacing: 6) {
                Text(item.name)
                    .foregroundStyle(item.isVisited ? Pop.ink : Pop.muted)
                if showsPrefecture, !item.prefectureName.isEmpty {
                    Text(item.prefectureName)
                        .font(.caption)
                        .foregroundStyle(Pop.muted)
                }
                if !item.isVisited, showBadgeAreaOnMap != nil {
                    Image(systemName: "map")
                        .font(.caption)
                        .foregroundStyle(Pop.theme)
                }
            }
        } icon: {
            Image(systemName: item.isVisited ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isVisited ? Pop.theme : Pop.muted)
        }
        .font(.subheadline.weight(item.isVisited ? .bold : .regular))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsPrefecture ? "\(item.prefectureName)\(item.name)" : item.name)
        .accessibilityValue(item.isVisited ? "訪問済み" : "未訪問")

        if !item.isVisited, let showBadgeAreaOnMap {
            Button {
                showBadgeAreaOnMap(.municipality(code: item.code, prefectureCode: item.prefectureCode))
            } label: {
                label
            }
            .buttonStyle(.plain)
            .accessibilityHint("地図でこの街を表示します")
        } else {
            label
        }
    }

    private func expandButton(isExpanded: Bool, total: Int, toggle: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { toggle() }
        } label: {
            Label(isExpanded ? "閉じる" : "すべて見る(\(total))", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                .font(.subheadline.weight(.bold))
        }
        .tint(Pop.theme)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func prefectureCountsCard(_ status: BadgeStatus) -> some View {
        let threshold = status.definition.tiers.first ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            Text("市区町村をたくさん訪れた都道府県")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            ForEach(status.progress.prefectureCounts.prefix(5)) { prefecture in
                HStack {
                    Text(prefecture.name)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(prefecture.visited) / \(threshold)か所")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .foregroundStyle(Pop.ink)
                PopProgressBar(fraction: threshold > 0 ? Double(prefecture.visited) / Double(threshold) : 0)
                    .accessibilityLabel("\(prefecture.name)の進み具合")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
    }

    // MARK: - 地図への導線

    @ViewBuilder
    private func mapButton(_ status: BadgeStatus) -> some View {
        if let showBadgeAreaOnMap, let target = status.mapTarget {
            Button {
                showBadgeAreaOnMap(target.focus)
            } label: {
                Label(target.title, systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .popPrimaryButton()
            .padding(.top, 4)
        }
    }
}
