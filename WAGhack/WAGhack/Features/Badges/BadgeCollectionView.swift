import SwiftUI

/// 旅の記録の「バッジ」タブ。獲得サマリー・次のチャレンジ・全バッジのスタンプ帳(固定順の3列)を並べる。
/// バッジの状態は持ち主(`MapScreen`)の`BadgeStore`をenvironmentで受け取る。プレビューなど渡されない場所では読み込み中の見た目になる。
struct BadgeCollectionView: View {
    @Environment(BadgeStore.self) private var badgeStore: BadgeStore?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var statuses: [BadgeStatus] { badgeStore?.statuses ?? [] }

    /// 基本は3列。文字を大きくしている時は名前が切れないよう2列にする。
    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    var body: some View {
        // 市区町村の一覧と同じPOPなカードを並べるため、ListではなくScrollViewにする。
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                summaryCard

                if let challenge = statuses.nextChallenge {
                    nextChallengeCard(challenge)
                }

                PopSectionHeader(title: "バッジコレクション")

                LazyVGrid(columns: columns, spacing: 18) {
                    if statuses.isEmpty {
                        // 訪問記録の評価を待つ間も同じ枠を並べ、評価後にレイアウトが跳ねないようにする。
                        ForEach(BadgeCatalog.all) { definition in
                            BadgeGridCell(definition: definition, status: nil)
                        }
                    } else {
                        ForEach(statuses) { status in
                            NavigationLink {
                                BadgeDetailView(badgeID: status.id)
                            } label: {
                                BadgeGridCell(definition: status.definition, status: status)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                PopFootnote("数え方は旅の記録と同じです。政令指定都市は区ごと、東京23区はそれぞれ1つとして数えます。準備中のバッジは、判定ができるようになると集められます。")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var summaryCard: some View {
        let earned = statuses.earnedCount
        let total = BadgeCatalog.all.count
        return VStack(alignment: .leading, spacing: 10) {
            MarkerHeading("あなたの旅のスタンプ")
            // 段階式のランクの数ではなく、獲得した種類の数を出す。
            HStack(alignment: .firstTextBaseline) {
                Text("集めたバッジ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.muted)
                Spacer()
                Text("\(earned) / \(total) 種類")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(Pop.ink)
                    .monospacedDigit()
            }
            PopProgressBar(fraction: Double(earned) / Double(total), fill: Pop.yellow)
                .accessibilityLabel("集めたバッジ")
            if badgeStore?.isLoaded == true, earned == 0 {
                Text("最初の街を訪れて、旅のスタンプを集めよう")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.ink)
            }
        }
        .padding(16)
        .popCard(shadow: Pop.yellow.opacity(0.7))
    }

    private func nextChallengeCard(_ status: BadgeStatus) -> some View {
        PopNavigationCard(shadow: Pop.yellow.opacity(0.5)) {
            BadgeDetailView(badgeID: status.id)
        } label: {
            HStack(spacing: 14) {
                BadgeStampView(
                    definition: status.definition,
                    earnedTierCount: status.earnedTierCount,
                    progressFraction: status.fractionToNext,
                    size: 64
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("次のチャレンジ")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Pop.muted)
                    Text(status.definition.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Pop.ink)
                    Text(status.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Pop.ink)
                    PopProgressBar(fraction: status.fractionToNext)
                        .accessibilityLabel("次のチャレンジの進み具合")
                    if let progressText = status.progressText {
                        Text(progressText)
                            .font(.caption)
                            .foregroundStyle(Pop.muted)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

/// スタンプ帳の1枚。スタンプが主役で、名前と状態の一言を下に添える。
private struct BadgeGridCell: View {
    let definition: BadgeDefinition
    /// nilなら評価待ち(読み込み中)。
    let status: BadgeStatus?

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

#Preview {
    NavigationStack {
        BadgeCollectionView()
    }
}
