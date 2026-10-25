import MapKit

/// 1つの市区町村(政令指定都市なら区の集まり)の区域。スポットがその区域の中にあるかを確かめるために使う。
nonisolated struct MunicipalityArea: Sendable {
    /// 区域のポリゴン。飛び地・島ごとに1つで、穴(他の市区町村に囲まれた部分)も持つ。
    let polygons: [BoundaryPolygon]
    /// 境界データの簡略化で生じる誤差(m)。境界のすぐ外に見える地点を、この距離までは区域内とみなす。
    let toleranceMeters: Double

    /// 全ポリゴンを囲む矩形。検索範囲に使う。
    var boundingBox: GeoBoundingBox? {
        GeoBoundingBox(enclosing: polygons.flatMap { [
            CLLocationCoordinate2D(latitude: $0.boundingBox.minLatitude, longitude: $0.boundingBox.minLongitude),
            CLLocationCoordinate2D(latitude: $0.boundingBox.maxLatitude, longitude: $0.boundingBox.maxLongitude),
        ] })
    }

    /// 地図の検索に渡す範囲。矩形の中心と、矩形を少し広げた幅。
    var searchRegion: MKCoordinateRegion? {
        guard let box = boundingBox else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (box.minLatitude + box.maxLatitude) / 2, longitude: (box.minLongitude + box.maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (box.maxLatitude - box.minLatitude) * 1.05,
            longitudeDelta: (box.maxLongitude - box.minLongitude) * 1.05
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    /// 地点が区域の中か。穴の中は外とみなす。境界から`toleranceMeters`以内なら(隣の市区町村の穴でない限り)中とみなす。
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let point = MKMapPoint(coordinate)
        let tolerance = toleranceMeters * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        // 矩形の判定用に許容値を度へ換算する。経度方向は緯度で縮むが、日本の緯度なら2倍取れば足りる。
        let toleranceDegrees = toleranceMeters / 111_000 * 2
        for polygon in polygons {
            let box = polygon.boundingBox
            guard coordinate.latitude >= box.minLatitude - toleranceDegrees,
                  coordinate.latitude <= box.maxLatitude + toleranceDegrees,
                  coordinate.longitude >= box.minLongitude - toleranceDegrees,
                  coordinate.longitude <= box.maxLongitude + toleranceDegrees else { continue }
            let exterior = polygon.exterior.map(MKMapPoint.init)
            let isInsideExterior = Self.ringContains(exterior, point)
            guard isInsideExterior || Self.distance(from: point, toRing: exterior) <= tolerance else { continue }
            // 穴の中(飛び地を囲む他の市区町村)は、穴の縁から離れていれば外とみなす。
            let isInHole = polygon.holes.contains { hole in
                let ring = hole.map(MKMapPoint.init)
                return Self.ringContains(ring, point) && Self.distance(from: point, toRing: ring) > tolerance
            }
            if !isInHole { return true }
        }
        return false
    }

    /// 偶奇規則による内外判定(`BoundaryFocusRect.contains`と同じ考え方を、座標列に直接適用する)。
    private static func ringContains(_ ring: [MKMapPoint], _ point: MKMapPoint) -> Bool {
        guard ring.count >= 3 else { return false }
        var isInside = false
        var previous = ring[ring.count - 1]
        for current in ring {
            if (current.y > point.y) != (previous.y > point.y) {
                let crossingX = (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
                if point.x < crossingX { isInside.toggle() }
            }
            previous = current
        }
        return isInside
    }

    private static func distance(from point: MKMapPoint, toRing ring: [MKMapPoint]) -> Double {
        guard var previous = ring.last else { return .infinity }
        var nearest = Double.infinity
        for current in ring {
            nearest = min(nearest, distance(from: point, toSegment: previous, current))
            previous = current
        }
        return nearest
    }

    private static func distance(from point: MKMapPoint, toSegment start: MKMapPoint, _ end: MKMapPoint) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared == 0 ? 0 : max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projectedX = start.x + t * dx
        let projectedY = start.y + t * dy
        return ((point.x - projectedX) * (point.x - projectedX) + (point.y - projectedY) * (point.y - projectedY)).squareRoot()
    }
}

/// 行政区域コードから、同梱の境界データの区域を引く。地図画面に依存しないので、どこから開いた詳細画面でも使える。
///
/// 内外の判定だけなので、中くらいの細かさのLOD2(100m間引き、1県あたり百数十KB)を使う。
/// 簡略化の許容距離がそのまま境界の誤差になるので、内外判定の許容値もこの距離にする。
/// リポジトリは地図用とは別に持つ(キャッシュが「同じファイルには同じフィルタ」を前提にしているため。`SilhouetteMapStore.load`参照)。
actor MunicipalityBoundaryLookup {
    static let shared = MunicipalityBoundaryLookup()

    private static let lod = 2
    private let repository = BoundaryRepository.bundled()

    /// 区域を返す。政令指定都市は境界データに市そのものの形が無いので、区のコードを`codes`に並べて渡す。
    /// 境界データが見つからなければnil(呼び出し側は検索できなかったものとして扱う)。
    func area(codes: [String]) async throws -> MunicipalityArea? {
        let manifest = try await repository.loadManifest()
        guard let level = manifest.lods.first(where: { $0.id == Self.lod }) else { return nil }
        let selector = BoundaryLODSelector(transitions: manifest.lodTransitions)
        // 行政区域コードの先頭2桁は都道府県コード。
        let prefectureCodes = Set(codes.map { String($0.prefix(2)) })
        var polygons: [BoundaryPolygon] = []
        for prefectureCode in prefectureCodes.sorted() {
            let boundaries = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: Self.lod, prefectureCode: prefectureCode),
                // 地図の表示と同じフィルタにする(このLODでは描かれない小さな島は、データ側で既に落ちている)。
                pieceFilter: BoundaryPieceFilter(visibleWidthMeters: selector.minimumVisibleWidthMeters(of: Self.lod))
            )
            polygons += boundaries.filter { codes.contains($0.code) }.flatMap(\.polygons)
        }
        guard !polygons.isEmpty else { return nil }
        return MunicipalityArea(polygons: polygons, toleranceMeters: level.intervalMeters)
    }
}
