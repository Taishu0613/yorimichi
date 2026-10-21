import CoreLocation
import Foundation
import Testing
@testable import WAGhack

@MainActor
struct FlightDetectorTests {
    private let detector = FlightDetector()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 東京駅付近。
    private func reading(
        latitude: CLLocationDegrees = 35.681, longitude: CLLocationDegrees = 139.767,
        at offset: TimeInterval = 0,
        speed: CLLocationSpeed = -1, speedAccuracy: CLLocationSpeedAccuracy = -1,
        altitude: CLLocationDistance = 0, verticalAccuracy: CLLocationAccuracy = -1
    ) -> FlightDetector.Reading {
        FlightDetector.Reading(
            latitude: latitude, longitude: longitude, timestamp: now.addingTimeInterval(offset),
            speed: speed, speedAccuracy: speedAccuracy, altitude: altitude, verticalAccuracy: verticalAccuracy
        )
    }

    private func state(previous: FlightDetector.Reading) -> FlightDetector.State {
        detector.evaluate(previous, state: FlightDetector.State()).updatedState
    }

    @Test func 速度も高度も分からない最初の位置は地上とみなす() {
        let result = detector.evaluate(reading(), state: FlightDetector.State())
        #expect(!result.isFlying)
        #expect(result.updatedState.lastSample?.timestamp == now)
    }

    @Test func 時速360km以上なら飛行中() {
        let result = detector.evaluate(reading(speed: 230, speedAccuracy: 5), state: FlightDetector.State())
        #expect(result.isFlying)
        #expect(result.updatedState.lastFlightEvidenceAt == now)
    }

    @Test func 新幹線の速さは飛行中とみなさない() {
        // 時速320km。
        let result = detector.evaluate(reading(speed: 89, speedAccuracy: 3), state: FlightDetector.State())
        #expect(!result.isFlying)
    }

    @Test func 精度の分からない速度は使わない() {
        let result = detector.evaluate(reading(speed: 230, speedAccuracy: -1), state: FlightDetector.State())
        #expect(!result.isFlying)
    }

    @Test func 標高4000m以上なら飛行中で富士山頂は地上() {
        #expect(detector.evaluate(reading(altitude: 10_000, verticalAccuracy: 30), state: FlightDetector.State()).isFlying)
        #expect(!detector.evaluate(reading(altitude: 3_776, verticalAccuracy: 30), state: FlightDetector.State()).isFlying)
        // 高度の精度が分からなければ使わない。
        #expect(!detector.evaluate(reading(altitude: 10_000, verticalAccuracy: -1), state: FlightDetector.State()).isFlying)
    }

    @Test func 直前の位置から時速360km以上で移動していれば飛行中() {
        // 経度1度(約90km)を10分で移動 = 時速約540km。
        let previous = state(previous: reading())
        let result = detector.evaluate(reading(longitude: 140.767, at: 600), state: previous)
        #expect(result.isFlying)
    }

    @Test func 直前の位置から新幹線程度の速さなら地上() {
        // 経度0.1度(約9km)を2分で移動 = 時速約270km。
        let previous = state(previous: reading())
        let result = detector.evaluate(reading(longitude: 139.867, at: 120), state: previous)
        #expect(!result.isFlying)
    }

    @Test func 間隔が短すぎる2点からは速さを求めない() {
        // 粗い位置の誤差で2km跳んでも、30秒間隔なら飛行中とはしない。
        let previous = state(previous: reading())
        let result = detector.evaluate(reading(longitude: 139.789, at: 30), state: previous)
        #expect(!result.isFlying)
    }

    @Test func 着陸後にまとめて届いた位置は飛行中とみなさない() {
        // 機内で位置が届かず、東京から福岡(約880km)の位置が2時間後に届いた。
        let previous = state(previous: reading())
        let result = detector.evaluate(reading(latitude: 33.59, longitude: 130.42, at: 2 * 60 * 60), state: previous)
        #expect(!result.isFlying)
    }

    @Test func 飛行中の根拠を見てから20分は降下中も飛行中とみなす() {
        let flying = detector.evaluate(reading(speed: 230, speedAccuracy: 5), state: FlightDetector.State())
        let descending = detector.evaluate(
            reading(latitude: 35.6, at: FlightDetector.holdDuration - 60), state: flying.updatedState
        )
        #expect(descending.isFlying)
        // 降下中の位置は根拠にならないので、保持の起点は最後に根拠を見た時刻のまま。
        #expect(descending.updatedState.lastFlightEvidenceAt == now)

        let landed = detector.evaluate(
            reading(latitude: 35.55, at: FlightDetector.holdDuration + 60), state: descending.updatedState
        )
        #expect(!landed.isFlying)
        #expect(landed.updatedState.lastFlightEvidenceAt == nil)
    }

    @Test func 判定の履歴は保存して読み戻せる() throws {
        let state = detector.evaluate(reading(speed: 230, speedAccuracy: 5), state: FlightDetector.State()).updatedState
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(FlightDetector.State.self, from: data) == state)
    }
}

@MainActor
struct AutoRecordPolicyTests {
    private let policy = AutoRecordPolicy()

    @Test func オンで解放済みで位置が十分細かければ記録する() {
        #expect(policy.shouldRecord(isEnabled: true, isUnlocked: true, horizontalAccuracy: 65))
        #expect(policy.shouldRecord(isEnabled: true, isUnlocked: true, horizontalAccuracy: AutoRecordPolicy.maximumHorizontalAccuracy))
    }

    @Test func 未購入やオフなら記録しない() {
        #expect(!policy.shouldRecord(isEnabled: true, isUnlocked: false, horizontalAccuracy: 65))
        #expect(!policy.shouldRecord(isEnabled: false, isUnlocked: true, horizontalAccuracy: 65))
    }

    @Test func 位置が粗いか不明なら記録しない() {
        #expect(!policy.shouldRecord(isEnabled: true, isUnlocked: true, horizontalAccuracy: 800))
        #expect(!policy.shouldRecord(isEnabled: true, isUnlocked: true, horizontalAccuracy: -1))
    }

    @Test func 自動記録したときの通知の文言() {
        #expect(NewMunicipalityAlertMessage.autoRecordedBody(areaName: "東京都中央区", recordedName: "東京都中央区")
            == "東京都中央区に初訪問です！よりみちに記録しました。")
        #expect(NewMunicipalityAlertMessage.autoRecordedBody(areaName: "埼玉県", recordedName: "埼玉県川口市")
            == "埼玉県に初訪問です！埼玉県川口市をよりみちに記録しました。")
    }
}

@MainActor
struct PremiumEntitlementPolicyTests {
    private let policy = PremiumEntitlementPolicy()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func 何も買っていなければ解放しない() {
        #expect(!policy.isUnlocked(by: [], now: now))
    }

    @Test func 買い切りを持っていれば解放する() {
        let lifetime = PremiumEntitlementPolicy.Entitlement(
            productID: PremiumProduct.lifetimeID, revocationDate: nil, expirationDate: nil
        )
        #expect(policy.isUnlocked(by: [lifetime], now: now))
    }

    @Test func 月額は期限内だけ解放する() {
        let active = PremiumEntitlementPolicy.Entitlement(
            productID: PremiumProduct.monthlyID, revocationDate: nil, expirationDate: now.addingTimeInterval(60)
        )
        let expired = PremiumEntitlementPolicy.Entitlement(
            productID: PremiumProduct.monthlyID, revocationDate: nil, expirationDate: now.addingTimeInterval(-60)
        )
        #expect(policy.isUnlocked(by: [active], now: now))
        #expect(!policy.isUnlocked(by: [expired], now: now))
    }

    @Test func 返金で取り消された購入では解放しない() {
        let revoked = PremiumEntitlementPolicy.Entitlement(
            productID: PremiumProduct.lifetimeID, revocationDate: now, expirationDate: nil
        )
        #expect(!policy.isUnlocked(by: [revoked], now: now))
    }

    @Test func 関係のない商品では解放しない() {
        let other = PremiumEntitlementPolicy.Entitlement(
            productID: "com.example.other", revocationDate: nil, expirationDate: nil
        )
        #expect(!policy.isUnlocked(by: [other], now: now))
    }
}

@MainActor
struct PremiumProductOrderTests {
    @Test func 届いた商品は月額と買い切りの順に並べ知らない商品は除く() {
        let received = [PremiumProduct.lifetimeID, "com.example.other", PremiumProduct.monthlyID]
        #expect(PremiumProduct.inDisplayOrder(received, id: { $0 }) == [PremiumProduct.monthlyID, PremiumProduct.lifetimeID])
    }

    @Test func 商品が届かなければ空になる() {
        #expect(PremiumProduct.inDisplayOrder([String](), id: { $0 }).isEmpty)
    }
}
