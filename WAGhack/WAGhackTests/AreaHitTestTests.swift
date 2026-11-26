import CoreLocation
import Testing
@testable import WAGhack

struct AreaHitTestTests {
    @Test func 区域の中をタップしたらその区域を返す() {
        let areas = [boundary("13101", "千代田区", square(0, 0, 1, 1)), boundary("13102", "中央区", square(1, 0, 2, 1))]
        #expect(AreaHitTest.boundary(containing: coordinate(1.5, 0.5), in: areas)?.name == "中央区")
    }

    @Test func どの区域にも入らない場所ならnil() {
        let areas = [boundary("13101", "千代田区", square(0, 0, 1, 1))]
        #expect(AreaHitTest.boundary(containing: coordinate(3, 3), in: areas) == nil)
    }

    @Test func コの字形のくぼみは区域の外() {
        // 西側が開いたコの字。外接矩形の中心(2, 2)はくぼみの中。
        let exterior = [
            coordinate(0, 0), coordinate(4, 0), coordinate(4, 4), coordinate(0, 4),
            coordinate(0, 3), coordinate(3, 3), coordinate(3, 1), coordinate(0, 1),
        ]
        let polygon = BoundaryPolygon(exterior: exterior, holes: [], boundingBox: box(0, 0, 4, 4))
        #expect(!AreaHitTest.contains(coordinate(2, 2), in: polygon))
        #expect(AreaHitTest.contains(coordinate(3.5, 2), in: polygon))
    }

    @Test func 穴の中は囲んでいる区域ではなく飛び地の区域になる() {
        let outer = BoundaryPolygon(
            exterior: ring(0, 0, 10, 10), holes: [ring(4, 4, 6, 6)], boundingBox: box(0, 0, 10, 10)
        )
        let areas = [
            AdministrativeBoundary(code: "11201", name: "川越市", prefectureCode: "11", polygons: [outer]),
            boundary("11000", "飛び地", square(4, 4, 6, 6)),
        ]
        #expect(AreaHitTest.boundary(containing: coordinate(5, 5), in: areas)?.name == "飛び地")
        #expect(AreaHitTest.boundary(containing: coordinate(2, 2), in: areas)?.name == "川越市")
    }

    @Test func 島を持つ区域はどの島をタップしても見つかる() {
        let islands = [square(0, 0, 1, 1).polygons[0], square(5, 5, 6, 6).polygons[0]]
        let areas = [AdministrativeBoundary(code: "13361", name: "大島町", prefectureCode: "13", polygons: islands)]
        #expect(AreaHitTest.boundary(containing: coordinate(5.5, 5.5), in: areas)?.name == "大島町")
    }

    private func boundary(_ code: String, _ name: String, _ shape: AdministrativeBoundary) -> AdministrativeBoundary {
        AdministrativeBoundary(code: code, name: name, prefectureCode: String(code.prefix(2)), polygons: shape.polygons)
    }

    private func square(_ west: Double, _ south: Double, _ east: Double, _ north: Double) -> AdministrativeBoundary {
        let polygon = BoundaryPolygon(
            exterior: ring(west, south, east, north), holes: [], boundingBox: box(west, south, east, north)
        )
        return AdministrativeBoundary(code: "", name: "", prefectureCode: "", polygons: [polygon])
    }

    private func ring(_ west: Double, _ south: Double, _ east: Double, _ north: Double) -> [CLLocationCoordinate2D] {
        [coordinate(west, south), coordinate(east, south), coordinate(east, north), coordinate(west, north)]
    }

    private func coordinate(_ longitude: Double, _ latitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func box(_ west: Double, _ south: Double, _ east: Double, _ north: Double) -> GeoBoundingBox {
        GeoBoundingBox(minLongitude: west, minLatitude: south, maxLongitude: east, maxLatitude: north)
    }
}
