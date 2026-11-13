import CoreLocation

/// 地図を長押しした場所の区域(市区町村、または都道府県ページなら都道府県)の名前。吹き出し(`MapAreaNameCallout`)に出す。
///
/// 市区町村名を地図に常に描くと、Appleマップ標準の地名(アプリから消せない)と二重に見えるため、
/// 名前は知りたい区域を長押ししたときだけ出す。
nonisolated struct PressedAreaName: Equatable, Sendable {
    /// 市区町村なら行政区域コード(5桁)、都道府県なら都道府県コード(2桁)。訪問済みかを調べるのに使う。
    let code: String
    let name: String
    /// 吹き出しを出す位置。長押しした場所そのもの(指を置いた所に名前が出る方が、どの区域の名前か分かりやすい)。
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.code == rhs.code && lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// 座標がどの区域に入っているかを、読み込み済みの境界の形から調べる。
nonisolated enum AreaHitTest {
    /// `coordinate`を含む区域。どれにも入っていなければ(海など)nil。
    /// 区域どうしは重ならないので、最初に見つかったものを返す。
    static func boundary(
        containing coordinate: CLLocationCoordinate2D, in boundaries: [AdministrativeBoundary]
    ) -> AdministrativeBoundary? {
        boundaries.first { boundary in
            boundary.polygons.contains { contains(coordinate, in: $0) }
        }
    }

    /// 島1つ(穴を含む)の中に座標があるか。穴(飛び地)の中は外として扱う。
    ///
    /// 座標から東へ伸ばした線が輪を横切る回数を、外周と穴を合わせて数え、奇数なら内側とする(偶奇規則)。
    /// 経緯度のまま平面として扱うが、日本の市区町村程度の大きさでは境界のごく近く以外で結果は変わらない。
    static func contains(_ coordinate: CLLocationCoordinate2D, in polygon: BoundaryPolygon) -> Bool {
        let box = polygon.boundingBox
        guard (box.minLatitude...box.maxLatitude).contains(coordinate.latitude),
              (box.minLongitude...box.maxLongitude).contains(coordinate.longitude) else { return false }
        var isInside = false
        for ring in [polygon.exterior] + polygon.holes where ring.count >= 3 {
            var previous = ring[ring.count - 1]
            for point in ring {
                // 片側だけを含める半開区間にして、頂点がちょうど同じ緯度にあっても二重に数えない。
                if (point.latitude > coordinate.latitude) != (previous.latitude > coordinate.latitude) {
                    let ratio = (coordinate.latitude - previous.latitude) / (point.latitude - previous.latitude)
                    let crossingLongitude = previous.longitude + ratio * (point.longitude - previous.longitude)
                    if crossingLongitude > coordinate.longitude {
                        isInside.toggle()
                    }
                }
                previous = point
            }
        }
        return isInside
    }
}
