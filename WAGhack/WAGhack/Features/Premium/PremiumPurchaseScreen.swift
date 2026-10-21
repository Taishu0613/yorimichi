import os
import StoreKit
import SwiftUI

/// 有料機能「自動で記録」の購入画面。月額と買い切りを並べ、購入の復元もここから行う。
///
/// 商品の名前・説明・価格・購入ボタンはStoreKitの`ProductView`に任せる。App Store Connectに登録した内容と
/// 端末の地域の価格がそのまま出るため、価格を自前で書かずに済み、購入の確認画面もOS標準になる。
/// 却下した案: `StoreView`は商品の一覧だけで、何ができるようになるかの説明を上に置けないため、`ProductView`を並べた。
///
/// 商品は先に`Product.products(for:)`で読み込んでから`ProductView`に渡す。IDだけを渡す形では、商品が見つからない
/// (App Store Connectに未登録・通信できない)ときに読み込み中の表示のまま止まり、買えない理由が分からなかったため。
struct PremiumPurchaseScreen: View {
    private enum ProductsState {
        case loading
        case loaded([Product])
        /// 商品が1つも見つからなかった、または読み込みに失敗した。
        case unavailable
    }

    /// 購入または復元で解放されたときに呼ぶ。閉じるのはこの画面が行う。
    let onUnlocked: () -> Void

    @Environment(PremiumStore.self) private var premiumStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var productsState: ProductsState = .loading
    private static let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "Premium")

    /// 自動更新サブスクリプションでは、利用規約へのリンクをアプリ内に置く必要がある(App Store審査ガイドライン3.1.2)。
    /// 独自の規約を用意していないため、Appleの標準使用許諾契約を使う。
    private static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// プライバシーポリシーへのリンクも同じく必要。リポジトリ Taishu0613/yorimichi-support のGitHub Pagesで公開している。
    private static let privacyPolicyURL = URL(string: "https://taishu0613.github.io/yorimichi-support/privacy/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    products

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
                        HStack(spacing: 16) {
                            Link("利用規約", destination: Self.termsOfUseURL)
                            Link("プライバシーポリシー", destination: Self.privacyPolicyURL)
                        }
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
            .task { await loadProducts() }
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

    @ViewBuilder
    private var products: some View {
        switch productsState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        case .loaded(let products):
            VStack(spacing: 12) {
                ForEach(products) { product in
                    ProductView(product)
                        .padding()
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        case .unavailable:
            VStack(spacing: 12) {
                Text("商品情報を読み込めませんでした")
                    .font(.headline)
                Text("通信状況を確認して、もう一度お試しください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("再試行") {
                    Task { await loadProducts() }
                }
                .buttonStyle(.bordered)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func loadProducts() async {
        productsState = .loading
        do {
            let products = PremiumProduct.inDisplayOrder(
                try await Product.products(for: PremiumProduct.allIDs), id: \.id
            )
            if products.isEmpty {
                // App Store Connectに未登録、またはStoreKit Configurationを使わずに起動した。
                Self.logger.error("購入できる商品が見つかりませんでした")
                productsState = .unavailable
            } else {
                productsState = .loaded(products)
            }
        } catch {
            Self.logger.error("商品を読み込めませんでした: \(error.localizedDescription, privacy: .public)")
            productsState = .unavailable
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
