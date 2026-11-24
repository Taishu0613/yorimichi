import CoreLocation
import Foundation

/// 新幹線・高速道路など時速80km以上で移動している間だけ、裏でもGPSで位置を追い続けるかを決める。
/// 位置情報・SwiftDataには依存しない。
///
/// ふだんの裏での判定は「大幅な位置の変化」に頼っていて、iOSはこれをおおむね5分に1回までしか知らせない。
/// 新幹線の5分は約24kmで、その間に通り抜けた市区町村は判定されず通知も来なかった。
/// 速い間だけ位置を追い続け、1分に1回判定する(ユーザーの指定)。
struct HighSpeedTrackingPolicy {
    /// 追い続け始める速さ。時速80km。
    static let minimumSpeed: CLLocationSpeed = 80 / 3.6
    /// 追い続けている間の判定(住所の確認)の間隔。
    static let checkInterval: TimeInterval = 60
    /// 時速80km未満がこれだけ続いたら追うのをやめる。駅での停車や渋滞(数分)ではやめない。
    static let slowDurationToStop: TimeInterval = 10 * 60

    struct Decision: Equatable {
        let shouldTrack: Bool
        /// 最後に速く動いていた日時。呼び出し側が持ち、次の判定に渡す。
        let lastFastAt: Date?
    }

    /// - Parameter speed: 端末が測った速度か、直前の位置から求めた速さ(m/s)。分からなければnil(今の状態を保つ)。
    func decide(isTracking: Bool, speed: CLLocationSpeed?, at timestamp: Date, lastFastAt: Date?) -> Decision {
        if let speed, speed >= Self.minimumSpeed {
            return Decision(shouldTrack: true, lastFastAt: timestamp)
        }
        guard isTracking else { return Decision(shouldTrack: false, lastFastAt: lastFastAt) }
        // 速さが分からない・遅い位置が届いても、最後に速かった時からの経過で判断する。
        guard let lastFastAt, timestamp.timeIntervalSince(lastFastAt) >= Self.slowDurationToStop else {
            return Decision(shouldTrack: true, lastFastAt: lastFastAt)
        }
        return Decision(shouldTrack: false, lastFastAt: nil)
    }
}
