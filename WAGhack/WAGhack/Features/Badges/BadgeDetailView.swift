import SwiftUI

/// バッジの詳細から地図へ向かう先。地図を動かすのは持ち主の`MapScreen`なので、ここでは行き先だけを表す。
enum BadgeMapFocus {
    /// 東京23区全体。
    case tokyoSpecialWards
    /// 都道府県全体。
    case prefecture(code: String)
}

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
        let items = status.progress.checklist
        let visibleItems = showsAllTargets ? items : Array(items.prefix(Self.collapsedTargetCount))
        return VStack(alignment: .leading, spacing: 12) {
            Text("あなたの歩いた街")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                ForEach(visibleItems) { item in
                    Label {
                        Text(item.name)
                            .foregroundStyle(item.isVisited ? Pop.ink : Pop.muted)
                    } icon: {
                        Image(systemName: item.isVisited ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isVisited ? Pop.theme : Pop.muted)
                    }
                    .font(.subheadline.weight(item.isVisited ? .bold : .regular))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.name)
                    .accessibilityValue(item.isVisited ? "訪問済み" : "未訪問")
                }
            }
            if items.count > Self.collapsedTargetCount {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showsAllTargets.toggle() }
                } label: {
                    Label(showsAllTargets ? "閉じる" : "すべて見る(\(items.count))", systemImage: showsAllTargets ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                }
                .tint(Pop.theme)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
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
        if let showBadgeAreaOnMap, let target = mapFocus(for: status) {
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

    /// 地図で探す先。まだ訪れていない対象がある時だけ出す。
    private func mapFocus(for status: BadgeStatus) -> (focus: BadgeMapFocus, title: String)? {
        guard status.isAvailable, !status.isComplete else { return nil }
        switch status.definition.id {
        case .tokyo23:
            return (.tokyoSpecialWards, "地図で未訪問の区を探す")
        case .localExplorer:
            guard let top = status.progress.prefectureCounts.first else { return nil }
            return (.prefecture(code: top.code), "地図で\(top.name)を探検する")
        default:
            return nil
        }
    }
}
