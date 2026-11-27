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

    @Test func バッジの共有文はバッジ名とハッシュタグとストアのリンク() {
        #expect(BadgeShareCardContent.shareText(badgeName: "はじめの一歩") == "バッジ「はじめの一歩」を獲得しました #よりみち\n\(url)")
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

/// バッジ・豆知識・初訪問のカードの見本の画像を書き出す。ふだんのテストでは動かさない。
///
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardKindsSampleRenderer ...`
@MainActor
struct ShareCardKindsSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func バッジ_豆知識_初訪問の見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // バッジ: 段階式のバッジをシルバーで獲得した架空の記録。
        let definition = try #require(BadgeCatalog.all.first { $0.isTiered && $0.isAvailable })
        let progress = BadgeProgress(definition: definition, value: definition.tiers[1])
        let achievedAt = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20))
        let status = BadgeStatus(
            progress: progress,
            achievement: BadgeAchievement(tierCount: 2, achievedAt: achievedAt, tierAchievedAt: achievedAt, announcedTierCount: 2)
        )
        let badge = BadgeShareCardContent(status: status)
        for layout in ShareCardLayout.allCases {
            try write(BadgeShareCardView(content: badge, layout: layout), layout: layout, name: "badge", in: directory)
        }

        // 豆知識(名古屋市のみどころ)と初訪問(名古屋市、写真なし)。名古屋市は区を集めた地図になる。
        let store = SilhouetteMapStore()
        let repository = BoundaryRepository.bundled()
        let manifest = try await repository.loadManifest()
        let wards = try await repository.boundaries(
            in: manifest.files(in: .municipalities, lod: 2, prefectureCode: "23"),
            pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 100_000)
        ).map(\.code).filter { $0.hasPrefix("231") && $0 != "23100" }
        let target = ShareMunicipalityTarget(code: "23100", name: "名古屋市", prefectureName: "愛知県", wardCodes: Set(wards))
        await target.loadMap(in: store)
        let map = try #require(target.map(in: store))
        let snapshots = ShareMapSnapshotStore()

        let trivia = TriviaShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true,
            topic: .highlights("名古屋市は、愛知県の県庁所在地で、中部地方の中心となる大都市だ。1610年に徳川家康が名古屋城を築き、清須の町をまるごと移した「清須越し」で町ができた。久屋大通と若宮大通は、幅100mの広い道路だ。熱田神宮には、三種の神器の一つ、草薙剣が祀られている。人口は東京23区、横浜市、大阪市に次ぐ多さだ。名古屋城は市の中区にある。")
        )
        let legend = TriviaShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: false,
            topic: .legend("名古屋城の天守の金鯱は、何度も盗難にあった。1876年には鱗3枚がはがされ、1937年には北の鯱の鱗58枚から金が盗まれた。江戸時代には、盗賊の柿木金助が大凧に乗って天守に近づき、鯱の鱗を盗んだという話が作られ、歌舞伎でも演じられた。")
        )
        let firstVisit = FirstVisitShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 124, total: 1_918)
        )
        for layout in ShareCardLayout.allCases {
            let triviaKey = ShareMapSnapshotStore.Key(id: target.snapshotID, box: layout == .story ? .triviaStory : .triviaSquare)
            await snapshots.loadBackdropIfNeeded(for: triviaKey, map: map)
            for (name, content) in [("trivia-nagoya-highlights", trivia), ("trivia-nagoya-legend", legend)] {
                try write(TriviaShareCardView(
                    content: content, layout: layout, map: map, highlightedCodes: target.highlightedCodes(in: map),
                    backdrop: snapshots.backdrop(for: triviaKey)
                ), layout: layout, name: name, in: directory)
            }

            let firstVisitKey = ShareMapSnapshotStore.Key(id: target.snapshotID, box: layout == .story ? .firstVisitStory : .firstVisitSquare)
            await snapshots.loadBackdropIfNeeded(for: firstVisitKey, map: map)
            try write(FirstVisitShareCardView(
                content: firstVisit, layout: layout, photo: nil, map: map, highlightedCodes: target.highlightedCodes(in: map),
                backdrop: snapshots.backdrop(for: firstVisitKey)
            ), layout: layout, name: "first-visit-nagoya", in: directory)
        }
    }

    private func write(_ view: some View, layout: ShareCardLayout, name: String, in directory: URL) throws {
        let image = try #require(ShareCardRenderer.render(view, layout: layout))
        #expect(image.size.width * image.scale == layout.pixelSize.width)
        let data = try #require(image.pngData())
        try data.write(to: directory.appendingPathComponent("share-card-\(name)-\(layout.rawValue).png"))
    }
}
