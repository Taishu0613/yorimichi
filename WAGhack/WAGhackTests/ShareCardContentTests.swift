import Foundation
import Testing
import UIKit
@testable import WAGhack

struct ShareCardContentTests {
    private let calculator = ExplorationProgressCalculator()
    private let date = Date(timeIntervalSince1970: 1_795_000_000) // 2026-11-18 (UTC)

    @Test func 訪れた市区町村の数とApp_Storeのリンクを共有文に入れる() {
        let summary = calculator.summarize(
            municipalities: [entry("13101", "千代田区"), entry("13102", "中央区"), entry("37201", "高松市")],
            visitedCodes: ["13101", "13102"]
        )

        let content = ShareCardContent(summary: summary, date: date)

        #expect(content.shareText == "日本の2市区町村を訪れました #よりみち\nhttps://apps.apple.com/jp/app/id6805073599")
    }

    @Test func まだ1つも訪れていなければ0件とは書かずはじまりの文にする() {
        let summary = calculator.summarize(municipalities: [entry("13101", "千代田区")], visitedCodes: [])

        let content = ShareCardContent(summary: summary, date: date)

        #expect(!content.shareText.contains("0市区町村"))
        #expect(content.shareText.hasSuffix("#よりみち\nhttps://apps.apple.com/jp/app/id6805073599"))
    }

    @Test func 件数と完全踏破した都道府県を数える() {
        let summary = calculator.summarize(
            municipalities: [
                entry("13101", "千代田区"), entry("13102", "中央区"),
                entry("37201", "高松市"), entry("37202", "丸亀市"),
                entry("47201", "那覇市"),
            ],
            visitedCodes: ["13101", "37201", "37202"],
            explicitlyVisitedPrefectureCodes: ["47"]
        )

        let content = ShareCardContent(summary: summary, date: date)

        #expect(content.visitedMunicipalityCount == 3)
        #expect(content.totalMunicipalityCount == 5)
        #expect(content.visitedPrefectureCount == 3)
        #expect(content.totalPrefectureCount == 3)
        // 香川(37)だけがすべての市区町村を訪れている。沖縄は都道府県単独の記録なので完全踏破ではない。
        #expect(content.completedPrefectureCount == 1)
        #expect(content.achievementText == "50%達成")
    }

    @Test func 塗りの単位で塗る区画のコードを切り替える() {
        let summary = calculator.summarize(
            municipalities: [entry("13101", "千代田区"), entry("47201", "那覇市")],
            visitedCodes: ["13101"],
            explicitlyVisitedPrefectureCodes: ["47"]
        )

        let content = ShareCardContent(summary: summary, date: date)

        #expect(content.visitedCodes(for: .municipalities) == ["13101"])
        // 都道府県だけの塗りでは、市区町村を訪れていない都道府県単独の記録も塗る。
        #expect(content.visitedCodes(for: .prefectures) == ["13", "47"])
    }

    @Test func 日付は端末の言語によらず日本語で書く() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(ShareCardContent.dateText(for: date, calendar: calendar) == "2026年11月18日")
    }

    @Test func 書き出す画像はSNSの推奨サイズで横360ptを3倍にする() {
        #expect(ShareCardLayout.story.pixelSize == CGSize(width: 1080, height: 1920))
        #expect(ShareCardLayout.square.pixelSize == CGSize(width: 1080, height: 1080))
        #expect(ShareCardLayout.story.pointSize.width == 360)
    }

    private func entry(_ code: String, _ name: String) -> ExplorationMunicipality {
        ExplorationMunicipality(
            code: code, name: name, prefectureCode: String(code.prefix(2)),
            prefectureName: String(code.prefix(2)), isPrefecture: false
        )
    }
}

/// シェア用カードの見本の画像を書き出す。ふだんのテストでは動かさない。
///
/// 書き出すときは、環境変数でフォルダを渡して実行する:
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardSampleRenderer ...`
@MainActor
struct ShareCardSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func 見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // アプリに同梱した境界データから、本物の地図と市区町村の一覧を作る。
        let store = SilhouetteMapStore()
        await store.loadShareCardMapsIfNeeded()
        let maps = try #require(store.shareCardMaps)
        let repository = BoundaryRepository.bundled()
        let manifest = try await repository.loadManifest()
        let municipalities = try await repository.boundaries(
            in: manifest.files(in: .municipalities, lod: 0, intersecting: GeoBoundingBox(minLongitude: -180, minLatitude: -90, maxLongitude: 180, maxLatitude: 90)),
            pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 700_000)
        )
        let entries = municipalities.map {
            ExplorationMunicipality(code: $0.code, name: $0.name, prefectureCode: $0.prefectureCode, prefectureName: $0.prefectureCode, isPrefecture: false)
        }

        // 架空の旅: 東京23区・香川県(完全踏破)・札幌・京都・福岡・沖縄本島の一部などで約120市区町村。
        let codes = entries.map(\.code)
        var visited: Set<String> = []
        visited.formUnion(codes.filter { $0.hasPrefix("131") })             // 東京23区
        visited.formUnion(codes.filter { $0.hasPrefix("37") })              // 香川県すべて
        visited.formUnion(codes.filter { $0.hasPrefix("011") }.prefix(10))  // 札幌市の区
        visited.formUnion(codes.filter { $0.hasPrefix("261") }.prefix(11))  // 京都市の区
        visited.formUnion(codes.filter { $0.hasPrefix("401") }.prefix(14))  // 北九州市・福岡市の区
        visited.formUnion(codes.filter { $0.hasPrefix("141") }.prefix(18))  // 横浜市の区
        visited.formUnion(codes.filter { $0.hasPrefix("272") }.prefix(12))  // 大阪府の市
        visited.formUnion(codes.filter { $0.hasPrefix("472") }.prefix(8))   // 沖縄県の市
        visited.formUnion(codes.filter { $0.hasPrefix("042") }.prefix(6))   // 宮城県の市
        visited.formUnion(codes.filter { $0.hasPrefix("172") }.prefix(5))   // 石川県の市
        let summary = ExplorationProgressCalculator().summarize(municipalities: entries, visitedCodes: visited)
        let content = ShareCardContent(summary: summary, date: .now)

        for layout in ShareCardLayout.allCases {
            for fill in ShareCardFill.allCases {
                let image = try #require(ShareCardRenderer.render(content: content, layout: layout, fill: fill, maps: maps))
                let data = try #require(image.pngData())
                #expect(image.size.width * image.scale == layout.pixelSize.width)
                #expect(image.size.height * image.scale == layout.pixelSize.height)
                try data.write(to: directory.appendingPathComponent("share-card-\(layout.rawValue)-\(fill.rawValue).png"))
            }
        }
    }
}
