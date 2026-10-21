import CoreLocation
import Foundation

/// 初訪問を知らせるときに、その場で記録まで済ませるか(有料機能「自動で記録」)を決める。
/// 位置情報・StoreKit・SwiftDataには依存しない。
struct AutoRecordPolicy {
    /// 自動記録に使う位置の精度の上限(m)。通知の判定(1,000m)より厳しくしてある。
    /// 通知は境界付近で取り違えてもユーザーが開いて確かめられるが、記録は残ってしまうため。
    /// これより粗い位置のときは自動記録せず、従来の「記録しませんか？」の通知にする。仮の値で、実機で調整する。
    static let maximumHorizontalAccuracy: CLLocationAccuracy = 500

    func shouldRecord(isEnabled: Bool, isUnlocked: Bool, horizontalAccuracy: CLLocationAccuracy) -> Bool {
        isEnabled && isUnlocked
            && horizontalAccuracy >= 0 && horizontalAccuracy <= Self.maximumHorizontalAccuracy
    }
}
