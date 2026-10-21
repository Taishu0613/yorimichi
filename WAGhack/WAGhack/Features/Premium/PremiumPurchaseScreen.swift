import StoreKit
import SwiftUI

/// 有料機能「自動で記録」の購入画面。月額と買い切りを並べ、購入の復元もここから行う。
///
/// 商品の名前・説明・価格・購入ボタンはStoreKitの`ProductView`に任せる。App Store Connectに登録した内容と
/// 端末の地域の価格がそのまま出るため、価格を自前で書かずに済み、購入の確認画面もOS標準になる。
/// 却下した案: `StoreView`は商品の一覧だけで、何ができるようになるかの説明を上に置けないため、`ProductView`を並べた。
struct PremiumPurchaseScreen: View {
    /// 購入または復元で解放されたときに呼ぶ。閉じるのはこの画面が行う。
    let onUnlocked: () -> Void

    @Environment(PremiumStore.self) private var premiumStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var errorMessage: String?

    /// 自動更新サブスクリプションでは、利用規約へのリンクをアプリ内に置く必要がある(App Store審査ガイドライン3.1.2)。
    /// 独自の規約を用意していないため、Appleの標準使用許諾契約を使う。
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 12) {
                        ForEach(PremiumProduct.allIDs, id: \.self) { productID in
                            ProductView(id: productID)
                                .padding()
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Button {
                        Task { await restore() }
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("購入を復元")
                        }
                    }
                    .disabled(isRestoring)

                    VStack(spacing: 8) {
                        Text("月額プランは、期間の終了の24時間前までに解約しない限り自動で更新されます。解約はApp Storeのサブスクリプションの設定から行えます。")
                        Link("利用規約", destination: Self.termsOfUseURL)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .tint(.teal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
            .onInAppPurchaseCompletion { _, result in
                do {
                    if try await premiumStore.handlePurchaseCompletion(result) {
                        unlock()
                    }
                } catch {
                    errorMessage = "購入できませんでした。時間をおいて、もう一度お試しください。"
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(.teal))
                .accessibilityHidden(true)
            Text("自動で記録")
                .font(.title2.weight(.bold))
            Text("初訪問の通知と一緒に、その場所をよりみちに自動で記録します。アプリを開かなくても、旅の記録が残ります。飛行機に乗っている間は記録しません。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                Label(LocationUsageAssurance.battery, systemImage: "leaf")
                Label(LocationUsageAssurance.privacy, systemImage: "lock.iphone")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await premiumStore.restorePurchases()
            if premiumStore.isUnlocked {
                unlock()
            } else {
                errorMessage = "復元できる購入が見つかりませんでした。"
            }
        } catch StoreKitError.userCancelled {
            // サインインを取りやめた。何も伝えない。
        } catch {
            errorMessage = "購入を復元できませんでした。通信状況を確認して、もう一度お試しください。"
        }
    }

    private func unlock() {
        onUnlocked()
        dismiss()
    }
}

#Preview {
    PremiumPurchaseScreen(onUnlocked: {})
        .environment(PremiumStore())
}
