import CoreLocation
import Foundation
import MapKit
import SwiftUI
import Testing
import UIKit
@testable import WAGhack

/// バッジ・豆知識・初訪問のカードの文言と、本物の地図を重ねる計算。
struct ShareCardKindsTests {
    private let url = "https://apps.apple.com/jp/app/id6805073599"

    // MARK: - 共有する文

    @Test func バッジの共有文はバッジ名と入手条件とハッシュタグとストアのリンク() {
        #expect(
            BadgeShareCardContent.shareText(badgeName: "はじめの足あと", condition: "市区町村をひとつ訪れる")
                == "バッジ「はじめの足あと」を獲得しました(市区町村をひとつ訪れる) #よりみち\n\(url)"
        )
    }

    // MARK: - バッジの入手条件

    private func condition(_ id: BadgeID, earnedTierCount: Int) throws -> String {
        let definition = try #require(BadgeCatalog.all.first { $0.id == id })
        return BadgeShareCardContent.conditionText(definition: definition, earnedTierCount: earnedTierCount)
    }

    @Test func 入手条件は判定の種類ごとに達成条件の文から作る() throws {
        // 訪れた市区町村の数
        #expect(try condition(.firstStep, earnedTierCount: 1) == "市区町村をひとつ訪れる")
        // 訪れた都道府県の数
        #expect(try condition(.prefectureTraveler, earnedTierCount: 4) == "47都道府県すべてを訪れる")
        // 1つの都道府県の市区町村の数
        #expect(try condition(.localExplorer, earnedTierCount: 1) == "同じ都道府県の市区町村を10か所訪れる")
        // 名前の付いた目的地(補足の二文目は落とす)
        #expect(try condition(.helloMetropolis, earnedTierCount: 1) == "池袋(豊島区)・新宿(新宿区)・渋谷(渋谷区)の3か所を訪れる")
        // 対象の市区町村
        #expect(try condition(.tokyo23, earnedTierCount: 3) == "東京23区をすべて訪れる")
        // 同じ名前の組
        #expect(try condition(.twinTowns, earnedTierCount: 1) == "ちがう都道府県にある同じ名前の市区町村を1組訪れる")
        // 数字の種類
        #expect(try condition(.numberTraveler, earnedTierCount: 1) == "名前に入っている数字を3種類集める")
        // 近くに集まる市区町村
        #expect(try condition(.quadrupleBoundary, earnedTierCount: 1) == "記録した場所がおたがい1km以内にある、4つの市区町村を訪れる")
        // 地域ごとに1つ以上
        #expect(try condition(.threeCapitals, earnedTierCount: 1) == "東京23区・京都市・大阪市の区を、それぞれ1つ以上訪れる")
    }

    @Test func 段階式の入手条件は獲得したランクの閾値で_未獲得なら最初の段階() throws {
        #expect(try condition(.footprintCollector, earnedTierCount: 0) == "市区町村を10か所訪れる")
        #expect(try condition(.footprintCollector, earnedTierCount: 1) == "市区町村を10か所訪れる")
        #expect(try condition(.footprintCollector, earnedTierCount: 3) == "市区町村を100か所訪れる")
        #expect(try condition(.footprintCollector, earnedTierCount: 9) == "市区町村を500か所訪れる")
    }

    @Test func 判定のあるバッジはどれも一文の入手条件を持つ() {
        for definition in BadgeCatalog.all where definition.isAvailable {
            for tierCount in 1...definition.tiers.count {
                let text = BadgeShareCardContent.conditionText(definition: definition, earnedTierCount: tierCount)
                #expect(!text.isEmpty, "\(definition.name)")
                #expect(!text.contains("。"), "\(definition.name): \(text)")
            }
        }
    }

    // MARK: - 市区町村のシェア画面で出せるカード

    @Test func 訪れた街は初訪問とみどころと都市伝説とできることを出す() {
        let kinds = MunicipalityShareSubject.availableKinds(
            isVisited: true, highlightsText: "名古屋市は…", legendText: "金鯱は…", hasSpots: true
        )
        #expect(kinds == [.firstVisit, .highlights, .legend, .spots])
    }

    @Test func まだ行っていない街は初訪問を出さない() {
        let kinds = MunicipalityShareSubject.availableKinds(
            isVisited: false, highlightsText: "名古屋市は…", legendText: "金鯱は…", hasSpots: true
        )
        #expect(kinds == [.highlights, .legend, .spots])
    }

    @Test func 都市伝説が決まり文句の街とスポットが無い街はその種類を出さない() {
        let kinds = MunicipalityShareSubject.availableKinds(
            isVisited: true, highlightsText: "白石区は…", legendText: "札幌市白石区には、特に有名な怪談・都市伝説はありません。", hasSpots: false
        )
        #expect(kinds == [.firstVisit, .highlights])
        let nothing = MunicipalityShareSubject.availableKinds(isVisited: false, highlightsText: " ", legendText: "", hasSpots: false)
        #expect(nothing.isEmpty)
    }

    @Test func 押した入口の種類が出せなければ出せる最初の種類で開く() {
        let target = ShareMunicipalityTarget(code: "01104", name: "札幌市白石区", prefectureName: "北海道")
        let subject = MunicipalityShareSubject(
            target: target, isVisited: false, highlightsText: "白石区は…",
            legendText: "札幌市白石区には、特に有名な怪談・都市伝説はありません。", spots: []
        )
        #expect(subject.initialKind(preferred: .legend) == .highlights)
        #expect(subject.initialKind(preferred: .firstVisit) == .highlights)
        #expect(subject.initialKind(preferred: .highlights) == .highlights)
        #expect(subject.canShare)
    }

    @Test func 豆知識の共有文は市区町村名とハッシュタグとストアのリンク() {
        let highlights = TriviaShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true, topic: .highlights("…"))
        #expect(highlights.shareText == "名古屋市の豆知識 #よりみち\n\(url)")
        let spot = TriviaShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: false, topic: .spot(name: "名古屋城", line: "…"))
        #expect(spot.shareText == "名古屋市でできること「名古屋城」 #よりみち\n\(url)")
    }

    @Test func 初訪問の共有文は全国の訪問数を添え_0件なら数を書かない() {
        let content = FirstVisitShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 123, total: 1_918)
        )
        #expect(content.shareText == "名古屋市に初訪問！ これで全国123市区町村 #よりみち\n\(url)")
        let empty = FirstVisitShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 0, total: 1_918))
        #expect(empty.shareText == "名古屋市に初訪問！ #よりみち\n\(url)")
    }

    // MARK: - シェアできる豆知識

    @Test func 都市伝説が無い街の決まり文句と空欄はシェアしない() {
        #expect(!TriviaShareCardContent.isShareableLegend("札幌市白石区には、特に有名な怪談・都市伝説はありません。"))
        #expect(!TriviaShareCardContent.isShareableLegend("札幌市白石区には、特に有名な怪談・都市伝説はありません。\n"))
        #expect(!TriviaShareCardContent.isShareableLegend("  "))
        #expect(TriviaShareCardContent.isShareableLegend("名古屋城の天守の金鯱は、何度も盗難にあった。"))
        #expect(!TriviaShareCardContent.isShareableHighlights(""))
        #expect(TriviaShareCardContent.isShareableHighlights("名古屋市は、愛知県の県庁所在地だ。"))
    }

    // MARK: - 本物の地図を重ねる計算

    @Test func 撮る範囲は_経緯度の枠がシルエットの位置に来るよう外へ広げる() {
        let frame = GeoBoundingBox(minLongitude: 136.6, minLatitude: 34.5, maxLongitude: 137.9, maxLatitude: 35.4)
        let frameRect = ShareMapSnapshotGeometry.mapRect(of: frame)
        let content = CGRect(x: 20, y: 10, width: 200, height: 200 * frameRect.height / frameRect.width)
        let box = CGSize(width: 300, height: 260)
        let rect = ShareMapSnapshotGeometry.snapshotMapRect(geoFrame: frame, contentRect: content, boxSize: box)

        // 枠の左上・右下の経緯度が、枠の中の`content`の角に来る。
        let scale = rect.width / Double(box.width)
        let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: frame.maxLatitude, longitude: frame.minLongitude))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: frame.minLatitude, longitude: frame.maxLongitude))
        #expect(abs((topLeft.x - rect.minX) / scale - content.minX) < 0.001)
        #expect(abs((topLeft.y - rect.minY) / scale - content.minY) < 0.001)
        #expect(abs((bottomRight.x - rect.minX) / scale - content.maxX) < 0.001)
        #expect(abs((bottomRight.y - rect.minY) / scale - content.maxY) < 0.001)
        // 縦横の縮尺が同じ(地図が伸び縮みしない)。
        #expect(abs(rect.height / Double(box.height) - scale) / scale < 0.000_001)
    }

    @Test func 撮れた地図にずれが無ければ枠ぴったりに置き_ずれていれば合わせて動かす() {
        let content = CGRect(x: 20, y: 30, width: 100, height: 80)
        let image = CGSize(width: 300, height: 200)
        #expect(ShareMapSnapshotGeometry.imageFrame(imageSize: image, actualContentRect: content, expectedContentRect: content)
            == CGRect(origin: .zero, size: image))
        // 画像の中で5pt右にずれて写っていたら、画像を5pt左に置く。
        let shifted = ShareMapSnapshotGeometry.imageFrame(
            imageSize: image, actualContentRect: content.offsetBy(dx: 5, dy: 0), expectedContentRect: content
        )
        #expect(shifted == CGRect(x: -5, y: 0, width: 300, height: 200))
    }

    @Test func メルカトル図法のシルエットはMapKitの平面と同じ位置になる() throws {
        // 名古屋駅あたり。県の枠の中での割合が、MapKitの平面(Webメルカトル)での割合と一致する。
        let frame = GeoBoundingBox(minLongitude: 136.6, minLatitude: 34.5, maxLongitude: 137.9, maxLatitude: 35.4)
        let projection = SilhouetteProjection(frame: frame, targetPoints: 360, kind: .mercator)
        let coordinate = CLLocationCoordinate2D(latitude: 35.17, longitude: 136.88)
        let normalized = projection.normalized(projection.point(coordinate))
        let rect = ShareMapSnapshotGeometry.mapRect(of: frame)
        let point = MKMapPoint(coordinate)
        #expect(abs(normalized.x - (point.x - rect.minX) / rect.width) < 0.000_01)
        #expect(abs(normalized.y - (point.y - rect.minY) / rect.height) < 0.000_01)
        #expect(abs(projection.aspectRatio - rect.width / rect.height) < 0.000_01)
    }

    @Test func シルエットは下にAppleマップのロゴの分を空けて収める() {
        let box = ShareCardMapBox(width: 300, height: 200, padding: 10)
        let rect = box.contentRect(aspectRatio: 3)
        #expect(rect.maxY <= 200 - ShareCardMapBox.attributionClearance + 0.001)
        #expect(rect.minX >= 10)
        #expect(abs(rect.width / rect.height - 3) < 0.001)
    }
}

/// バッジのカードの見本の画像を書き出す。ふだんのテストでは動かさない(地図・市区町村のカードの見本は`ShareCardSampleRenderer`)。
///
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardKindsSampleRenderer ...`
@MainActor
struct ShareCardKindsSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func バッジの見本の画像を書き出す() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // 足あとコレクターをゴールドで獲得した架空の記録と、補足付きの条件を持つ都会にこんにちは。
        for (id, tierCount) in [(BadgeID.footprintCollector, 3), (.helloMetropolis, 1)] {
            let definition = try #require(BadgeCatalog.all.first { $0.id == id })
            let achievedAt = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20))
            let status = BadgeStatus(
                progress: BadgeProgress(definition: definition, value: definition.tiers[tierCount - 1]),
                achievement: BadgeAchievement(tierCount: tierCount, achievedAt: achievedAt, tierAchievedAt: achievedAt, announcedTierCount: tierCount)
            )
            let badge = BadgeShareCardContent(status: status)
            for size in ShareCardSize.allCases {
                let image = try #require(ShareCardRenderer.render(BadgeShareCardView(content: badge, size: size), size: size))
                #expect(image.size.width * image.scale == size.pixelSize.width)
                let data = try #require(image.pngData())
                try data.write(to: directory.appendingPathComponent("share-card-badge-\(id.rawValue)-\(size.rawValue).png"))
            }
        }
    }
}
