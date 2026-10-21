import Foundation

/// 有料機能(初訪問の自動記録)を解放する商品。App Store Connectに登録する商品IDと一致させること。
/// どちらか1つを持っていれば解放する。IDを変えると購入済みの人が解放されなくなるので変えないこと。
enum PremiumProduct {
    /// 自動更新サブスクリプション(月額200円)。サブスクリプショングループ「よりみち プレミアム」に属する。
    static let monthlyID = "com.wakasugi.yorimichi.premium.monthly"
    /// 非消耗型(買い切り1,200円)。
    static let lifetimeID = "com.wakasugi.yorimichi.premium.lifetime"

    /// 購入画面に並べる順。
    static let allIDs = [monthlyID, lifetimeID]

    /// App Storeから届いた商品を`allIDs`の順に並べ、知らない商品を除く。届く順は保証されないため。
    static func inDisplayOrder<Item>(_ items: [Item], id: (Item) -> String) -> [Item] {
        allIDs.compactMap { productID in items.first { id($0) == productID } }
    }
}

/// StoreKitの購入記録から、有料機能を解放するかを決める。StoreKitには依存しない。
struct PremiumEntitlementPolicy {
    /// `Transaction`のうち判定に使う項目だけを写したもの。
    struct Entitlement: Equatable {
        let productID: String
        /// 返金などで取り消された日時。
        let revocationDate: Date?
        /// サブスクリプションの期限。買い切りではnil。
        let expirationDate: Date?
    }

    /// `Transaction.currentEntitlements`は期限切れや取り消し済みを基本的に含まないが、
    /// 端末の時刻や更新の届く順によっては残ることがあるため、ここでも確かめる。
    func isUnlocked(by entitlements: [Entitlement], now: Date) -> Bool {
        entitlements.contains { entitlement in
            guard PremiumProduct.allIDs.contains(entitlement.productID),
                  entitlement.revocationDate == nil
            else { return false }
            guard let expirationDate = entitlement.expirationDate else { return true }
            return expirationDate > now
        }
    }
}
