import CoreLocation
import Foundation

/// 飛行機に乗っているらしいかを、裏で届く位置から判定する。飛行中は上空を通っただけの市区町村なので、
/// 初訪問の通知も自動記録もしない。位置情報・通知・SwiftDataの状態は持たず、判定に必要な履歴は呼び出し側が保存する。
///
/// 根拠にするのは次のどれか。閾値はどれも仮の値で、実機で使って調整する。
/// - 端末が測った速度が時速360km以上。新幹線(営業最高 時速320km)は飛行機とみなさない。
/// - 標高4,000m以上。富士山頂(3,776m)は地上とみなす。
/// - 直前の位置からの移動の速さが時速360km以上。大幅な位置の変化では速度が測られない(-1)ことが多いため、
///   1〜30分の間隔で届いた2点から求める。間隔が短すぎると粗い位置の誤差で速く見え、
///   長すぎると「機内で位置が届かず着陸後にまとめて届いた」場合に着陸地まで飛行中と誤るため、範囲を絞る。
///   2点の位置の誤差(精度)の分は動いていないとみなして距離から差し引く。大幅な位置の変化は基地局・Wi-Fiによる
///   誤差1km近い位置で届くことがあり、新幹線(時速285〜320km)でも誤差の分だけ速く見えて飛行中と誤るため。
/// - 上の根拠を最後に見てから20分以内。降下中は速度・高度が閾値を下回るため、着陸まで続けて飛行中とみなす。
struct FlightDetector {
    /// 時速360km。
    static let minimumFlightSpeed: CLLocationSpeed = 100
    static let minimumFlightAltitude: CLLocationDistance = 4_000
    static let speedEstimationInterval: ClosedRange<TimeInterval> = 60...(30 * 60)
    static let holdDuration: TimeInterval = 20 * 60

    /// 判定に使う位置の項目。`CLLocation`から作るが、テストでは任意の値で作れるよう分けてある。
    struct Reading: Equatable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees
        let timestamp: Date
        /// m/s。測れていなければ負の値(`CLLocation.speed`と同じ)。
        var speed: CLLocationSpeed = -1
        var speedAccuracy: CLLocationSpeedAccuracy = -1
        /// 海抜(m)。
        var altitude: CLLocationDistance = 0
        /// 負の値なら高度は測れていない(`CLLocation.verticalAccuracy`と同じ)。
        var verticalAccuracy: CLLocationAccuracy = -1
        /// 位置の誤差(m)。負の値なら分からない(`CLLocation.horizontalAccuracy`と同じ)。
        var horizontalAccuracy: CLLocationAccuracy = -1
    }

    /// 起動をまたいで引き継ぐ判定の履歴。アプリは位置の変化で裏で起こされては終了されるため、呼び出し側が保存する。
    struct State: Codable, Equatable {
        struct Sample: Codable, Equatable {
            let latitude: CLLocationDegrees
            let longitude: CLLocationDegrees
            let timestamp: Date
            /// 位置の誤差(m)。この項目が無かった版で保存した履歴ではnil。
            var horizontalAccuracy: CLLocationAccuracy?
        }

        var lastSample: Sample?
        /// 最後に飛行中の根拠を見た日時。
        var lastFlightEvidenceAt: Date?
    }

    struct Result: Equatable {
        let isFlying: Bool
        let updatedState: State
    }

    func evaluate(_ reading: Reading, state: State) -> Result {
        var updatedState = state
        updatedState.lastSample = State.Sample(
            latitude: reading.latitude, longitude: reading.longitude, timestamp: reading.timestamp,
            horizontalAccuracy: reading.horizontalAccuracy
        )

        if hasFlightEvidence(reading, previous: state.lastSample) {
            updatedState.lastFlightEvidenceAt = reading.timestamp
            return Result(isFlying: true, updatedState: updatedState)
        }
        if let lastFlightEvidenceAt = state.lastFlightEvidenceAt,
           reading.timestamp.timeIntervalSince(lastFlightEvidenceAt) < Self.holdDuration {
            return Result(isFlying: true, updatedState: updatedState)
        }
        updatedState.lastFlightEvidenceAt = nil
        return Result(isFlying: false, updatedState: updatedState)
    }

    private func hasFlightEvidence(_ reading: Reading, previous: State.Sample?) -> Bool {
        if reading.speed >= 0, reading.speedAccuracy >= 0, reading.speed >= Self.minimumFlightSpeed {
            return true
        }
        if reading.verticalAccuracy > 0, reading.altitude >= Self.minimumFlightAltitude {
            return true
        }
        guard let previous else { return false }
        let interval = reading.timestamp.timeIntervalSince(previous.timestamp)
        guard Self.speedEstimationInterval.contains(interval) else { return false }
        let distance = CLLocation(latitude: reading.latitude, longitude: reading.longitude)
            .distance(from: CLLocation(latitude: previous.latitude, longitude: previous.longitude))
        // 精度が分からない位置は差し引かない。
        let uncertainty = max(reading.horizontalAccuracy, 0) + max(previous.horizontalAccuracy ?? 0, 0)
        return (distance - uncertainty) / interval >= Self.minimumFlightSpeed
    }
}

extension FlightDetector.Reading {
    init(_ location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            speed: location.speed,
            speedAccuracy: location.speedAccuracy,
            altitude: location.altitude,
            verticalAccuracy: location.verticalAccuracy,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }
}
