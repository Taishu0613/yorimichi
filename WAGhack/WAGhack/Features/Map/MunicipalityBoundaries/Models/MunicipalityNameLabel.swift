import CoreLocation

/// 地図に描く市区町村名1つ。`MunicipalityNameLabelLayer`が描く。
///
/// Appleマップ標準の地名ラベルは文字の大きさ・色をアプリから変えられず、お店などのアイコンに混ざって
/// 小さく見えるため、市区町村名だけはアプリで描いている。
nonisolated struct MunicipalityNameLabel: Identifiable, Equatable, Sendable {
    /// 行政区域コード(`Municipality.code`と一致)。1つの市区町村に名前は1つだけ描く。
    let code: String
    /// 地図に出す名前。政令指定都市の区は区の名前だけにする(`MunicipalityNameLabelPolicy.displayName`)。
    let name: String
    let coordinate: CLLocationCoordinate2D

    var id: String { code }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.code == rhs.code && lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// 市区町村名をどこに・どの縮尺で描くかの決まり。
nonisolated enum MunicipalityNameLabelPolicy {
    /// 1文字あたりの幅の目安(pt)。地図の文字(`MunicipalityNameLabelLayer`の13pt太字)に、フチ取りの分を足している。
    static let pointsPerCharacter: CGFloat = 14
    /// 名前を描くのに必要な区域の幅の下限(pt)。短い名前(「北区」など)でも、これより小さく見える区域には描かない。
    /// 小さな区域に詰めて描くと、隣の区域の名前と重なって読めなくなるため。
    static let minimumAreaWidthPoints: CGFloat = 56

    /// 地図に出す名前。政令指定都市の区は市の名前を外す(「名古屋市中区」→「中区」)。
    /// 区の集まりが1つの市であることは市の外周の縁取りで分かり、市の名前まで付けると長くて隣と重なりやすいため。
    static func displayName(of name: String) -> String {
        guard let cityName = DesignatedCity.cityName(ofWard: name) else { return name }
        return String(name.dropFirst(cityName.count))
    }

    /// 区域が画面上で`widthMeters`×`heightMeters`に見えるとき、`name`を描いてよいか。
    /// 文字が区域の幅に収まり、かつ1行ぶんの高さがあるときだけ描く。
    static func fits(name: String, widthMeters: Double, heightMeters: Double, metersPerPoint: Double) -> Bool {
        guard metersPerPoint.isFinite, metersPerPoint > 0 else { return false }
        let widthPoints = CGFloat(widthMeters / metersPerPoint)
        let heightPoints = CGFloat(heightMeters / metersPerPoint)
        let neededWidth = max(minimumAreaWidthPoints, CGFloat(name.count) * pointsPerCharacter)
        return widthPoints >= neededWidth && heightPoints >= pointsPerCharacter * 2
    }

    /// 名前を置く位置。区域の中に必ず収まる点を返す。
    ///
    /// 外接矩形の中心や重心は、三日月形・L字形の区域では区域の外(隣の市区町村や海)に出てしまう。
    /// そこで区域を横に切る線を何本か引き、区域の内側にある最も長い区間の中点を使う。
    /// 横に長い区間ほど横書きの名前が収まりやすい。切る線は中央から順に試し、同じ長さなら中央に近い方を選ぶ。
    /// 穴(飛び地)の部分は区域の外として扱う。
    static func labelCoordinate(
        exterior: [CLLocationCoordinate2D], holes: [[CLLocationCoordinate2D]], boundingBox: GeoBoundingBox
    ) -> CLLocationCoordinate2D {
        let rings = [exterior] + holes
        let height = boundingBox.maxLatitude - boundingBox.minLatitude
        // 中央、少し上下、さらに上下の順に試す。
        let fractions = [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8]
        var best: (latitude: Double, west: Double, east: Double)?
        for fraction in fractions {
            let latitude = boundingBox.minLatitude + height * fraction
            guard let segment = widestInteriorSegment(of: rings, atLatitude: latitude) else { continue }
            if let current = best, current.east - current.west >= segment.east - segment.west { continue }
            best = (latitude, segment.west, segment.east)
        }
        guard let best else {
            // 形が壊れていて区間が取れないときだけ外接矩形の中心にする。
            return CLLocationCoordinate2D(
                latitude: (boundingBox.minLatitude + boundingBox.maxLatitude) / 2,
                longitude: (boundingBox.minLongitude + boundingBox.maxLongitude) / 2
            )
        }
        return CLLocationCoordinate2D(latitude: best.latitude, longitude: (best.west + best.east) / 2)
    }

    /// 緯度`latitude`の横線が区域の内側を通る区間のうち、最も長いもの。
    /// 横線と輪の交点を西から順に並べると、偶数番目と奇数番目の間が内側になる(偶奇規則)。
    private static func widestInteriorSegment(
        of rings: [[CLLocationCoordinate2D]], atLatitude latitude: Double
    ) -> (west: Double, east: Double)? {
        var crossings: [Double] = []
        for ring in rings where ring.count >= 3 {
            var previous = ring[ring.count - 1]
            for point in ring {
                // 片側だけを含める半開区間にして、頂点がちょうど横線上にあっても交点を二重に数えない。
                if (point.latitude > latitude) != (previous.latitude > latitude) {
                    let ratio = (latitude - previous.latitude) / (point.latitude - previous.latitude)
                    crossings.append(previous.longitude + ratio * (point.longitude - previous.longitude))
                }
                previous = point
            }
        }
        crossings.sort()
        var widest: (west: Double, east: Double)?
        for pairStart in stride(from: 0, to: crossings.count - 1, by: 2) {
            let west = crossings[pairStart]
            let east = crossings[pairStart + 1]
            if let current = widest, current.east - current.west >= east - west { continue }
            widest = (west, east)
        }
        return widest
    }
}
