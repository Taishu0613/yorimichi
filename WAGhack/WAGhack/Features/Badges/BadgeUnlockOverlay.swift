import SwiftUI

/// 新しくバッジを獲得したときに地図の上へ重ねる知らせ。スタンプが押されてインクが広がる演出と、軽い触覚で達成を伝える。
///
/// 地図のシート(旅の記録・儀式)と提示が競合しないよう、シートではなく`MapScreen`のoverlayに重ねる
/// (通知の案内カード`NewMunicipalityAlertAnnouncement`と同じ方式)。いつ出すかは`MapScreen`が決める。
/// 複数を同時に獲得したときは1枚にまとめ、何枚も続けて大きく出さない。
struct BadgeUnlockOverlay: View {
    let announcement: BadgeAnnouncement
    /// はじめての評価のまとめで、獲得済みのスタンプを並べるために使う。
    let statuses: [BadgeStatus]
    let showBadges: () -> Void
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SoundController.self) private var soundController: SoundController?
    /// スタンプが押された後か。演出の始まりと触覚のきっかけに使う。
    @State private var isStamped = false

    /// 並べるスタンプの上限。超えた分は名前の一覧だけで伝える。
    private static let maxStampCount = 3

    private struct Stamp: Identifiable {
        let definition: BadgeDefinition
        let tierCount: Int
        var id: BadgeID { definition.id }
    }

    private var stamps: [Stamp] {
        switch announcement {
        case .initialSummary:
            statuses.filter(\.isEarned).map { Stamp(definition: $0.definition, tierCount: $0.earnedTierCount) }
        case .newlyEarned(let unlocks):
            unlocks.compactMap { unlock in
                BadgeCatalog.definition(for: unlock.id).map { Stamp(definition: $0, tierCount: unlock.tierCount) }
            }
        }
    }

    private var title: String {
        switch announcement {
        case .initialSummary: "これまでの旅のスタンプ"
        case .newlyEarned: "新しい旅のスタンプ！"
        }
    }

    private var message: String {
        switch announcement {
        case .initialSummary(let count):
            return "これまでの旅で\(count)種類のバッジを獲得しています"
        case .newlyEarned:
            guard stamps.count == 1, let stamp = stamps.first else { return "\(stamps.count)つのバッジを獲得しました" }
            return stamp.definition.name
        }
    }

    private var detail: String {
        if case .newlyEarned = announcement, stamps.count == 1, let stamp = stamps.first {
            guard stamp.definition.isTiered, let rank = BadgeRank(earnedTierCount: stamp.tierCount) else {
                return stamp.definition.summary
            }
            return stamp.tierCount > 1 ? "\(rank.name)にランクアップ！" : "\(rank.name)を獲得"
        }
        return stamps.map(\.definition.name).joined(separator: "・")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)

            card
                .padding(.horizontal, 28)
                .frame(maxWidth: 440)
        }
        .onAppear {
            soundController?.play(.celebration)
            // 視差効果を減らす設定では、押す動きを省いて押された後の姿だけを見せる(触覚は鳴らす)。
            if reduceMotion {
                isStamped = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.58).delay(0.15)) {
                    isStamped = true
                }
            }
        }
        .sensoryFeedback(trigger: isStamped) { _, stamped in stamped ? .success : nil }
    }

    private var card: some View {
        VStack(spacing: 14) {
            MarkerHeading(title)
                .multilineTextAlignment(.center)
            stampRow
                .padding(.vertical, 8)
            Text(message)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Pop.ink)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Pop.muted)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(action: showBadges) {
                    Text("バッジを見る")
                        .frame(maxWidth: .infinity)
                }
                .popPrimaryButton()
                Button(action: dismiss) {
                    Text("閉じる")
                        .frame(maxWidth: .infinity)
                }
                .popSecondaryButton()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .popCard(fill: Pop.paper, shadow: Pop.yellow.opacity(0.8), cornerRadius: 28, shadowOffset: 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var stampRow: some View {
        let visible = Array(stamps.prefix(Self.maxStampCount))
        let size: CGFloat = visible.count == 1 ? 132 : 84
        return HStack(spacing: -size * 0.12) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, stamp in
                ZStack {
                    if !reduceMotion {
                        inkRing(color: stamp.definition.artwork.primary, delay: Double(index) * 0.12)
                    }
                    BadgeStampView(definition: stamp.definition, earnedTierCount: stamp.tierCount, size: size)
                        .scaleEffect(isStamped ? 1 : 1.7)
                        .opacity(isStamped ? 1 : 0)
                }
                .frame(width: size, height: size)
                // 複数のときは少しずつ遅らせて、1枚ずつ押していくように見せる。
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.58).delay(0.15 + Double(index) * 0.12), value: isStamped)
            }
        }
        .accessibilityHidden(true)
    }

    /// スタンプが押された瞬間に、インクがにじんで外へ広がって消える輪。押す動き(spring)が着地する頃に合わせて広げる。
    private func inkRing(color: Color, delay: Double) -> some View {
        Circle()
            .stroke(color, lineWidth: 6)
            .keyframeAnimator(initialValue: InkRing(), trigger: isStamped) { content, ring in
                content
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: 0.3 + delay)
                    LinearKeyframe(0.55, duration: 0.05)
                    LinearKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.9, duration: 0.3 + delay)
                    SpringKeyframe(1.6, duration: 0.6)
                }
            }
    }
}

private struct InkRing {
    var scale: CGFloat = 0.9
    var opacity: Double = 0
}
