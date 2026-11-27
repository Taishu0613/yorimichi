import SwiftUI

/// 都道府県・政令指定都市の節目に届いたときに、地図のフッターのすぐ上へ出す小さな知らせ。「シェアする」でシェア画面を開く。
///
/// バッジ獲得の知らせ(`BadgeUnlockBanner`)と同じ形・同じ場所にし、地図の操作を止めないよう画面は暗くせず、
/// しばらくすると自分で消える。節目の達成そのものは地図の演出(触覚・効果音)で既に伝えているので、ここでは音を鳴らさない。
/// 見逃しても、都道府県・政令指定都市の画面のシェアボタンから同じカードを作れる。
struct ShareMilestoneBanner: View {
    let milestone: ShareMilestone
    let share: () -> Void
    let dismiss: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    /// 自分で消えるまでの時間。バッジの知らせ(6秒)より短くし、シェアしない人の邪魔にならないようにする。
    /// 読み上げを使っている時は、読み終える前に消えないよう消さない。
    private static let displayDuration: Duration = .seconds(5)

    private var systemImage: String {
        switch milestone.kind {
        case .prefecture(let percent): percent == 100 ? "crown.fill" : "flag.fill"
        case .designatedCityComplete: "crown.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            PopIconBadge(systemImage: systemImage, fill: Pop.yellow, size: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("節目達成！")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Pop.muted)
                Text(milestone.message)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button("シェアする", systemImage: "square.and.arrow.up", action: share)
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
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement("節目達成。\(milestone.message)").post()
        }
        .task {
            guard !voiceOverEnabled else { return }
            do {
                try await Task.sleep(for: Self.displayDuration)
            } catch {
                // 消える前に閉じられた・シェアするを押された(ビューが消えた)だけなので、何もしない。
                return
            }
            dismiss()
        }
    }
}

/// `MapScreen`に節目の知らせとシェア画面を付ける。`MapScreen`の`body`に直接並べると型検査が重くなりすぎるため分けている。
///
/// 知らせを出すかどうか(`canPresent`)は`MapScreen`が決める。バッジ獲得の知らせと同じく、記録の流れや旅の記録・設定を
/// 見ている間は待ち、地図だけが見えている落ち着いた時に出す。チュートリアル中は`MapScreen`自体が有効でないので出ない。
struct ShareMilestonePresentation: ViewModifier {
    let store: ShareMilestoneStore
    let canPresent: Bool
    /// フッターの上に出すための下の余白。
    let bottomPadding: CGFloat
    let silhouetteStore: SilhouetteMapStore
    /// 出している知らせ。持ち主は`MapScreen`(バッジの知らせと重ねないよう、出しているかを`MapScreen`も見る)。
    @Binding var milestone: ShareMilestone?
    /// 開いているシェア画面の範囲。nilなら開いていない。
    @Binding var shareScope: ShareScope?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Trigger: Equatable {
        let canPresent: Bool
        let nextID: String?
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let milestone {
                    ShareMilestoneBanner(milestone: milestone, share: { share(milestone) }, dismiss: dismiss)
                        .padding(.horizontal, 16)
                        .padding(.bottom, bottomPadding)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: Trigger(canPresent: canPresent, nextID: store.nextAnnouncement?.id)) {
                await presentWhenCalm()
            }
            .sheet(item: $shareScope) { scope in
                ShareMapSheet(initialScope: scope, silhouetteStore: silhouetteStore)
            }
    }

    /// 記録の直後は地図の演出・初訪問のシートが続くので、少し落ち着くのを待ってから出す。
    /// 待っている間に状態が変われば(`Trigger`が変わる)このタスクごと取り消される。
    private func presentWhenCalm() async {
        guard canPresent, let next = store.nextAnnouncement else { return }
        do {
            try await Task.sleep(for: .milliseconds(800))
        } catch {
            return
        }
        store.markAnnounced(next)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            milestone = next
        }
    }

    private func share(_ milestone: ShareMilestone) {
        self.milestone = nil
        shareScope = milestone.scope
    }

    private func dismiss() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            milestone = nil
        }
    }
}
