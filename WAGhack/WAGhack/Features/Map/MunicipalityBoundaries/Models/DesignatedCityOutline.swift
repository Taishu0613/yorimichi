import CoreLocation

/// 政令指定都市の外周を、区の形からつなぎ合わせて作る。
///
/// 境界データは区単位で、市そのものの形を持たない。区どうしの境は隣り合う2つの区が同じ頂点で持つため
/// (`BoundaryData`の生成で隙間・重なりを修復済み)、全区の辺のうち1回しか現れない辺だけを残せば市の外周になる。
/// 残った辺は各頂点でちょうど2本ずつつながるので(全20市・全LODで確認)、たどると閉じた輪になる。
/// 市の内側に他の市町村の飛び地があれば、その周りも輪として残る(縁取りとしてはそれで正しい)。
nonisolated enum DesignatedCityOutline {
    /// 区のポリゴン(外周と穴)をまとめた、市の輪郭の輪。大きい順に並べる(`BoundaryPieceFilter`の先頭は常に描く規則に合わせる)。
    /// 輪は始点と終点が同じ座標で閉じている。
    static func rings(of polygons: [BoundaryPolygon]) -> [BoundaryPolygon] {
        // 辺の向きは区によって逆になるため、向きを無視して数える。並びは最初に現れた順を保ち、結果を毎回同じにする。
        var edgeCounts: [Edge: Int] = [:]
        var edgeOrder: [(from: Point, to: Point)] = []
        var coordinates: [Point: CLLocationCoordinate2D] = [:]
        for polygon in polygons {
            for ring in [polygon.exterior] + polygon.holes {
                for (start, end) in zip(ring, ring.dropFirst()) {
                    let from = Point(start)
                    let to = Point(end)
                    guard from != to else { continue }
                    coordinates[from] = start
                    coordinates[to] = end
                    let edge = Edge(from, to)
                    if edgeCounts[edge] == nil { edgeOrder.append((from, to)) }
                    edgeCounts[edge, default: 0] += 1
                }
            }
        }
        let outerEdges = edgeOrder.filter { edgeCounts[Edge($0.from, $0.to)] == 1 }
        var neighbors: [Point: [Point]] = [:]
        for edge in outerEdges {
            neighbors[edge.from, default: []].append(edge.to)
            neighbors[edge.to, default: []].append(edge.from)
        }

        var used: Set<Edge> = []
        var rings: [BoundaryPolygon] = []
        for edge in outerEdges where !used.contains(Edge(edge.from, edge.to)) {
            used.insert(Edge(edge.from, edge.to))
            var points = [edge.from, edge.to]
            var current = edge.to
            while current != edge.from,
                  let next = neighbors[current]?.first(where: { !used.contains(Edge(current, $0)) }) {
                used.insert(Edge(current, next))
                points.append(next)
                current = next
            }
            let ring = points.compactMap { coordinates[$0] }
            guard ring.count >= 4, let box = GeoBoundingBox(enclosing: ring) else { continue }
            rings.append(BoundaryPolygon(exterior: ring, holes: [], boundingBox: box))
        }
        return rings.sorted { $0.boundingBox.longerSideMeters > $1.boundingBox.longerSideMeters }
    }

    /// 頂点を完全一致で比べるためのキー(`CLLocationCoordinate2D`はHashableでないため)。
    private struct Point: Hashable {
        let latitude: Double
        let longitude: Double

        init(_ coordinate: CLLocationCoordinate2D) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }
    }

    /// 向きを無視した辺。
    private struct Edge: Hashable {
        let a: Point
        let b: Point

        init(_ first: Point, _ second: Point) {
            if (first.latitude, first.longitude) < (second.latitude, second.longitude) {
                a = first
                b = second
            } else {
                a = second
                b = first
            }
        }
    }
}
