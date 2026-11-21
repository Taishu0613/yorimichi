//
//  LocationService.swift
//  WAGhack
//

import CoreLocation
import Foundation
import os

@MainActor
final class LocationService {
    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "Location")

    func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw LocationServiceError.servicesDisabled
        }

        switch locationManager.authorizationStatus {
        case .denied:
            throw LocationServiceError.authorizationDenied
        case .restricted:
            throw LocationServiceError.authorizationRestricted
        default:
            break
        }

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        // 最初に届く位置は前回の位置(キャッシュ)のことがあり、新幹線などで速く動いていると数km後ろの
        // 市区町村を返してしまう。新しく精度の足りた位置を少し待ち、待ちきれなければ最後に届いた位置を使う。
        let latest = LatestLocation()
        return try await withThrowingTaskGroup(of: CLLocation?.self) { group in
            group.addTask { try await self.waitForFreshPreciseLocation(recordingInto: latest) }
            group.addTask {
                try await Task.sleep(for: Self.maximumWaitForFreshLocation)
                return nil
            }
            while let result = try await group.next() {
                // 待ちきれなかった(nil)場合は、まだ1件も届いていなければ届くまで待ち続ける(従来どおり)。
                if let location = result ?? latest.location {
                    group.cancelAll()
                    return location
                }
            }
            throw LocationServiceError.locationUnavailable
        }
    }

    /// 現在地ボタン・記録で使う位置の新しさの上限(秒)。これより古い位置はキャッシュとみなす。
    /// 時速285kmで10秒は約800m。仮の値で、実機で調整する。
    nonisolated static let maximumLocationAge: TimeInterval = 10
    /// 現在地ボタン・記録で待つ位置の精度(m)。地図画面の自動判定と同じ基準。
    nonisolated static let preferredHorizontalAccuracy: CLLocationAccuracy = 100
    /// 新しく精度の足りた位置を待つ最長の時間。屋内などで届かなければ、最後に届いた位置で判定する。
    nonisolated static let maximumWaitForFreshLocation: Duration = .seconds(10)

    nonisolated static func isFreshAndPrecise(_ location: CLLocation, now: Date) -> Bool {
        location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= preferredHorizontalAccuracy
            && now.timeIntervalSince(location.timestamp) <= maximumLocationAge
    }

    /// 新しく精度の足りた位置が届いたら返す。それまでに届いた位置は`latest`に残す(待ちきれなかった時に使う)。
    private func waitForFreshPreciseLocation(recordingInto latest: LatestLocation) async throws -> CLLocation? {
        // iOS 17以降のAsyncSequenceを使い、必要な1件を得た時点で監視を終了する。
        for try await update in CLLocationUpdate.liveUpdates(.default) {
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                throw LocationServiceError.authorizationDenied
            }

            if update.authorizationRestricted {
                throw LocationServiceError.authorizationRestricted
            }

            if update.locationUnavailable {
                if let location = latest.location { return location }
                throw LocationServiceError.locationUnavailable
            }

            guard let location = update.location, location.horizontalAccuracy >= 0 else { continue }
            if Self.isFreshAndPrecise(location, now: .now) {
                return location
            }
            latest.location = location
        }

        return nil
    }

    /// 画面を開いている間の移動を見張るための、精度の足りた現在地の列。呼び出し側のループを抜ける
    /// (タスクがキャンセルされる)と監視も止まる。
    ///
    /// - 受け手の処理(住所の確認は通信を挟む)が終わるまでに届いた位置は最新の1件だけ残す。古い位置を
    ///   順に処理していくと、移動に対して判定がどんどん遅れていくため。
    /// - 許可が無い・取り消された場合は黙って終了する。ユーザーへの案内は現在地ボタン側の`currentLocation()`が担う。
    /// - 静止中はCore Locationが自動で更新を止めるため、止まっている間に電池を使い続けることはない。
    /// - 古い位置(監視を始めた直後に届く前回の位置のキャッシュ)は捨てる。精度の値はキャッシュでも良いままなので、
    ///   使うと前の市区町村で判定してしまい、次の判定まで(移動距離・間隔の条件を満たすまで)初訪問に気づけない。
    func accurateLocationUpdates(maximumHorizontalAccuracy: CLLocationAccuracy) -> AsyncStream<CLLocation> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task { [logger] in
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.default) {
                        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                            break
                        }
                        guard let location = update.location,
                              location.horizontalAccuracy >= 0,
                              location.horizontalAccuracy <= maximumHorizontalAccuracy,
                              Date.now.timeIntervalSince(location.timestamp) <= Self.maximumLocationAge
                        else { continue }
                        continuation.yield(location)
                    }
                } catch {
                    logger.error("現在地の監視が終了しました: \(error.localizedDescription, privacy: .public)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// 現在地を待つ間に届いた最後の位置。待ちきれなかった時に使う。
@MainActor
private final class LatestLocation {
    var location: CLLocation?
}

enum LocationServiceError: LocalizedError {
    case authorizationDenied
    case authorizationRestricted
    case locationUnavailable
    case servicesDisabled

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "位置情報の使用が許可されていません。設定アプリから位置情報を許可してください。"
        case .authorizationRestricted:
            "この端末では位置情報の使用が制限されています。"
        case .locationUnavailable:
            "現在地を取得できませんでした。屋外など、位置情報を取得しやすい場所で再度お試しください。"
        case .servicesDisabled:
            "端末の位置情報サービスがオフになっています。"
        }
    }
}
