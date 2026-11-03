import SwiftUI

/// 新しくバッジを獲得したときに、地図のフッターのすぐ上へ出す小さな知らせ。
///
/// 獲得はうれしいが、地図の操作や移動中の利用を止めないことを優先する。画面を暗くする大きなカードにはせず、
/// しばらくすると自分で消える。押すと詳細(複数ならバッジ図鑑)を開く。初訪問のお祝いなどの主要な演出とは
/// 重ねず、`MapScreen`がそれらの後の落ち着いた時に出す。複数を同時に獲得したときは1枚にまとめる。
/// 見逃しても、旅の記録の入口カード(「最近獲得」)とバッジ図鑑から後で確かめられる。
struct BadgeUnlockBanner: View {
    let announcement: BadgeAnnouncement
    /// はじめての評価のまとめで、獲得済みのスタンプを並べるために使う。
    let statuses: [BadgeStatus]
    let showBadges: () -> Void
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(SoundController.self) private var soundController: SoundController?
    /// スタンプが押された後か。演出の始まりと触覚のきっかけに使う。
    @State private var isStamped = false

    /// 自分で消えるまでの時間。読み上げを使っている時は、読み終える前に消えないよう消さない。
    private static let displayDuration: Duration = .seconds(6)

    private var unlockedDefinitions: [(definition: BadgeDefinition, tierCount: Int)] {
        switch announcement {
        case .initialSummary:
            statuses.filter(\.isEarned).map { ($0.definition, $0.earnedTierCount) }
        case .newlyEarned(let unlocks):
            unlocks.compactMap { unlock in
                BadgeCatalog.definition(for: unlock.id).map { ($0, unlock.tierCount) }
            }
        }
    }

    private var title: String {
        switch announcement {
        case .initialSummary: "これまでの旅のバッジ"
        case .newlyEarned: "バッジ獲得！"
        }
    }

    private var message: String {
        switch announcement {
        case .initialSummary(let count):
            return "これまでの旅で\(count)種類のバッジを獲得しています"
        case .newlyEarned:
            let unlocked = unlockedDefinitions
            guard unlocked.count == 1, let first = unlocked.first else {
                return "新しいバッジを\(unlocked.count)つ獲得"
            }
            if first.definition.isTiered, let rank = BadgeRank(earnedTierCount: first.tierCount) {
                if first.tierCount > 1 {
                    return "「\(first.definition.name)」が\(rank.name)にランクアップ"
                }
                return "「\(first.definition.name)」の\(rank.name)を獲得"
            }
            return "「\(first.definition.name)」を達成"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            stamp
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Pop.muted)
                Text(message)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button("詳しく見る", action: showBadges)
                .buttonStyle(.glassProminent)
                .tint(Pop.theme)
                .font(.footnote.weight(.bold))
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Pop.muted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: showBadges)
        .accessibilityElement(children: .contain)
        .onAppear {
            soundController?.play(.celebration)
            AccessibilityNotification.Announcement("\(title)。\(message)").post()
            // 動きを減らす設定では、押す動きを省いて押された後の姿だけを見せる(触覚は鳴らす)。
            if reduceMotion {
                isStamped = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.58).delay(0.1)) {
                    isStamped = true
                }
            }
        }
        .sensoryFeedback(trigger: isStamped) { _, stamped in stamped ? .success : nil }
        .task {
            guard !voiceOverEnabled else { return }
            do {
                try await Task.sleep(for: Self.displayDuration)
            } catch {
                // 消える前に閉じられた・詳しく見るを押された(ビューが消えた)だけなので、何もしない。
                return
            }
            dismiss()
        }
    }

    /// 獲得したスタンプ。複数なら最大3枚を少しずつずらして重ねる。
    private var stamp: some View {
        let shown = Array(unlockedDefinitions.prefix(3))
        return ZStack {
            ForEach(Array(shown.enumerated()), id: \.element.definition.id) { index, item in
                BadgeStampView(definition: item.definition, earnedTierCount: item.tierCount, size: 46)
                    .offset(x: CGFloat(index) * 8, y: CGFloat(index) * -3)
                    .zIndex(Double(-index))
            }
        }
        .frame(width: 46 + CGFloat(max(shown.count - 1, 0)) * 8, height: 50)
        .scaleEffect(isStamped ? 1 : 1.6)
        .opacity(isStamped ? 1 : 0)
        .accessibilityHidden(true)
    }
}
