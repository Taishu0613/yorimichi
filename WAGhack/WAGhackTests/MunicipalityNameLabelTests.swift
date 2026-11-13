import CoreLocation
import Testing
@testable import WAGhack

struct MunicipalityNameLabelTests {
    @Test func 政令指定都市の区は区の名前だけにする() {
        #expect(MunicipalityNameLabelPolicy.displayName(of: "横浜市保土ケ谷区") == "保土ケ谷区")
    }

    @Test func 東京の特別区や市町村は名前をそのまま出す() {
        #expect(MunicipalityNameLabelPolicy.displayName(of: "千代田区") == "千代田区")
        #expect(MunicipalityNameLabelPolicy.displayName(of: "高山市") == "高山市")
    }

    @Test func 名前が収まる大きさに見える区域には名前を描く() {
        // 10km四方の区域を1ptあたり100mで見ると100pt四方。「高山市」(3文字)は収まる。
        #expect(MunicipalityNameLabelPolicy.fits(name: "高山市", widthMeters: 10_000, heightMeters: 10_000, metersPerPoint: 100))
    }

    @Test func 小さく見える区域には名前を描かない() {
        // 3km四方を1ptあたり100mで見ると30pt四方。隣の名前と重なるので描かない。
        #expect(!MunicipalityNameLabelPolicy.fits(name: "北区", widthMeters: 3_000, heightMeters: 3_000, metersPerPoint: 100))
    }

    @Test func 長い名前は区域の幅に収まらなければ描かない() {
        // 70pt幅には5文字(約70pt)は収まるが、8文字は収まらない。
        #expect(MunicipalityNameLabelPolicy.fits(name: "南アルプス", widthMeters: 7_000, heightMeters: 7_000, metersPerPoint: 100))
        #expect(!MunicipalityNameLabelPolicy.fits(name: "横浜市保土ケ谷区", widthMeters: 7_000, heightMeters: 7_000, metersPerPoint: 100))
    }

    @Test func コの字形の区域でも名前は区域の内側に置く() {
        // 西側が開いたコの字。外接矩形の中心(2, 2)はくぼみの中で、区域の外になる。
        let exterior = [
            coordinate(0, 0), coordinate(4, 0), coordinate(4, 4), coordinate(0, 4),
            coordinate(0, 3), coordinate(3, 3), coordinate(3, 1), coordinate(0, 1),
        ]
        let point = MunicipalityNameLabelPolicy.labelCoordinate(
            exterior: exterior, holes: [], boundingBox: box(0, 0, 4, 4)
        )
        let isInBottomArm = point.latitude < 1
        let isInTopArm = point.latitude > 3
        let isInEastSide = point.longitude > 3
        #expect(isInBottomArm || isInTopArm || isInEastSide)
    }

    @Test func 穴の中には名前を置かない() {
        // 中央に大きな穴(飛び地)がある区域。
        let exterior = [coordinate(0, 0), coordinate(10, 0), coordinate(10, 10), coordinate(0, 10)]
        // 穴の縁を切る線の高さ(外接矩形の2〜8割)とずらし、縁の上にちょうど乗る点が出ないようにしている。
        let hole = [coordinate(1.5, 1.5), coordinate(8.5, 1.5), coordinate(8.5, 8.5), coordinate(1.5, 8.5)]
        let point = MunicipalityNameLabelPolicy.labelCoordinate(
            exterior: exterior, holes: [hole], boundingBox: box(0, 0, 10, 10)
        )
        let isInHole = (1.5...8.5).contains(point.longitude) && (1.5...8.5).contains(point.latitude)
        #expect(!isInHole)
    }

    @Test func 素直な形の区域では中央に置く() {
        let exterior = [coordinate(0, 0), coordinate(4, 0), coordinate(4, 2), coordinate(0, 2)]
        let point = MunicipalityNameLabelPolicy.labelCoordinate(
            exterior: exterior, holes: [], boundingBox: box(0, 0, 4, 2)
        )
        #expect(point.longitude == 2)
        #expect(point.latitude == 1)
    }

    private func coordinate(_ longitude: Double, _ latitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func box(_ west: Double, _ south: Double, _ east: Double, _ north: Double) -> GeoBoundingBox {
        GeoBoundingBox(minLongitude: west, minLatitude: south, maxLongitude: east, maxLatitude: north)
    }
}
