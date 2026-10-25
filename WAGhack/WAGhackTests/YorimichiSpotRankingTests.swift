import MapKit
import Testing
@testable import WAGhack

struct YorimichiSpotRankingTests {
    private func candidate(_ name: String, category: MKPointOfInterestCategory? = nil, offset: Double) -> SpotCandidate {
        // 重複とみなされないよう、候補ごとに約1kmずつ離す。
        SpotCandidate(name: name, category: category, coordinate: CLLocationCoordinate2D(latitude: 35.6 + offset * 0.01, longitude: 140.1), address: nil)
    }

    @Test func 寺は名前の末尾だけで判定し地名の寺は寺院にしない() {
        #expect(YorimichiSpotRanking.experience(name: "千葉寺", category: nil) == .temple)
        #expect(YorimichiSpotRanking.experience(name: "千葉寺きじばと公園", category: .park) == .park)
        #expect(YorimichiSpotRanking.experience(name: "千葉寺駅", category: nil) == .other)
    }

    @Test func 同じ区分は2件までにしてお店や区分の決まらない施設は選ばない() {
        let candidates = [
            candidate("千葉神社", offset: 0),
            candidate("寒川神社", offset: 1),
            candidate("登渡神社", offset: 2),
            candidate("サイゼリヤ千葉寺店", category: .restaurant, offset: 3),
            candidate("観光情報センター", offset: 4),
        ]

        let spots = YorimichiSpotRanking.select(candidates, municipalityCode: "12101")

        #expect(spots.map(\.name) == ["千葉神社", "寒川神社"])
    }
}
