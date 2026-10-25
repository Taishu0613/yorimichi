import SwiftUI

/// 「設定」画面(SettingsScreen)の、有料機能「自動で記録」の設定。初訪問の通知の設定のすぐ下に置く。
/// 未購入なら購入画面への入口、購入済みならスイッチを出す。
///
/// 購入画面のシートは、このSectionではなく一覧(List)の側に`autoRecordPurchaseSheet`で付ける。
/// Sectionに付けたモディファイアは中の行と脚注のそれぞれに付くため、同じフラグのシートが2つになり、
/// 開いた直後に閉じてしまっていた。
struct AutoRecordSettingsSection: View {
    /// アプリのルートで渡される。プレビューなど渡されない場所では何も出さない。
    @Environment(NewMunicipalityAlertMonitor.self) private var monitor: NewMunicipalityAlertMonitor?
    @Environment(PremiumStore.self) private var premiumStore: PremiumStore?
    @Binding var isPurchasePresented: Bool

    var body: some View {
        if let monitor, let premiumStore {
            Section {
                if premiumStore.isUnlocked {
                    Toggle(isOn: Binding(
                        get: { monitor.isAutoRecordEnabled },
                        set: { monitor.setAutoRecordEnabled($0) }
                    )) {
                        Label("自動で記録", systemImage: "checkmark.seal")
                    }
                    .tint(.teal)
                    // 通知と一緒に動く機能なので、通知がオフの間は操作できないようにする。
                    .disabled(!monitor.isEnabled)
                } else {
                    Button {
                        isPurchasePresented = true
                    } label: {
                        HStack {
                            Label("自動で記録", systemImage: "checkmark.seal")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("有料")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                }
            } header: {
                PopSectionHeader(title: "有料機能", marker: Pop.themeSoft)
            } footer: {
                Text(Self.footerText(isUnlocked: premiumStore.isUnlocked, isAlertEnabled: monitor.isEnabled))
            }
        }
    }

    private static func footerText(isUnlocked: Bool, isAlertEnabled: Bool) -> String {
        if !isUnlocked {
            return "初訪問の通知と一緒に、その場所を自動で記録します。飛行機に乗っている間は記録しません。"
        }
        if !isAlertEnabled {
            return "初訪問の通知をオンにすると使えます。"
        }
        return "アプリを閉じている間に初訪問の通知が届くとき、その場所も記録します。位置が大まかなときは記録せず、通知だけお知らせします。飛行機に乗っている間は通知も記録もしません。"
    }
}

extension View {
    /// `AutoRecordSettingsSection`の購入画面を出す。Sectionの外(一覧そのもの)に付けること。
    func autoRecordPurchaseSheet(isPresented: Binding<Bool>) -> some View {
        modifier(AutoRecordPurchaseSheetModifier(isPresented: isPresented))
    }
}

private struct AutoRecordPurchaseSheetModifier: ViewModifier {
    @Environment(NewMunicipalityAlertMonitor.self) private var monitor: NewMunicipalityAlertMonitor?
    @Environment(PremiumStore.self) private var premiumStore: PremiumStore?
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PremiumPurchaseScreen(onUnlocked: {
                    // 買ったのは使うためなので、そのままオンにする。通知がオフならスイッチだけ入り、通知をオンにすると動く。
                    monitor?.setAutoRecordEnabled(true)
                })
                // 旅の記録のシートと同じく、ガラスが透けないよう白で塗る。
                .presentationBackground(Pop.paper)
            }
            // サブスクリプションの期限切れや返金を、画面を開いたときに表示へ反映する。
            .task { await premiumStore?.refreshEntitlements() }
    }
}
