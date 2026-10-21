import Foundation
import Observation
import os
import StoreKit

/// 有料機能を解放しているかを持つ。購入の記録はStoreKit 2(App Store)が持っており、ここはそれを読むだけ。
///
/// - 解放の判定は`Transaction.currentEntitlements`から毎回導く。端末内の検証済みの記録を読むので通信は要らず、
///   裏で起こされたときの判定(`NewMunicipalityAlertMonitor`)でも使える。
/// - `isUnlocked`は画面表示用。起動直後に一瞬「未購入」に見えないよう、前回の判定結果をUserDefaultsに置いて初期値にする。
///   有料機能を実際に動かす前は、必ず`refreshEntitlements()`で確かめ直すこと(キャッシュは書き換えられうるため)。
///
/// 却下した案: 購入状態を自前で保存して正とする方式は、返金・期限切れ・別端末での購入を取りこぼすため採らなかった。
@Observable
final class PremiumStore {
    private static let cachedUnlockKey = "premium.isUnlocked"

    private(set) var isUnlocked: Bool

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "Premium")
    /// アプリが動いている間ずっと購入の更新(更新・返金・別端末での購入・承認待ちの完了)を受け取る。
    /// このストアはアプリと同じ期間だけ生きるので止めない。
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isUnlocked = userDefaults.bool(forKey: Self.cachedUnlockKey)
    }

    /// 購入の更新の受け取りを始め、解放状態を確かめ直す。アプリの起動直後に1回呼ぶ。
    /// 受け取りを始めないまま購入が届くと、その購入は完了扱いにならず次回起動時に再び届く。
    func start() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
    }

    /// 端末内の購入記録から解放状態を求め直す。
    @discardableResult
    func refreshEntitlements() async -> Bool {
        var entitlements: [PremiumEntitlementPolicy.Entitlement] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                // 署名を検証できない記録は改ざんの恐れがあるので数えない。
                logger.error("検証できない購入記録を無視しました")
                continue
            }
            entitlements.append(.init(
                productID: transaction.productID,
                revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate
            ))
        }
        let isUnlocked = PremiumEntitlementPolicy().isUnlocked(by: entitlements, now: .now)
        self.isUnlocked = isUnlocked
        userDefaults.set(isUnlocked, forKey: Self.cachedUnlockKey)
        return isUnlocked
    }

    /// 購入画面(`ProductView`)での購入が終わったときに呼ぶ。
    /// - Returns: 有料機能が解放されたか。承認待ち(ファミリーの承認など)・キャンセルではfalse。
    func handlePurchaseCompletion(_ result: Result<Product.PurchaseResult, any Error>) async throws -> Bool {
        switch result {
        case .success(.success(let verification)):
            await handle(verification)
            return isUnlocked
        case .success:
            // キャンセル、または承認待ち。承認されれば`Transaction.updates`から届く。
            return false
        case .failure(let error):
            throw error
        }
    }

    /// 別の端末や再インストール前に買ったものを、App Storeから取り寄せ直す。
    /// Apple IDへのサインインを求められることがあるため、ユーザーがボタンを押したときだけ呼ぶ。
    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else {
            logger.error("検証できない購入を受け取りました")
            return
        }
        // 完了を伝えないと、App Storeは同じ購入を次回起動時にも届け続ける。
        await transaction.finish()
        await refreshEntitlements()
    }
}
