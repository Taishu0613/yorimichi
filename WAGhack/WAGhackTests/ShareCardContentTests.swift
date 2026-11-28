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
        #expect(ShareCardSize.story.pixelSize == CGSize(width: 1080, height: 1920))
        #expect(ShareCardSize.square.pixelSize == CGSize(width: 1080, height: 1080))
        #expect(ShareCardSize.story.pointSize.width == 360)
    }

    private func entry(_ code: String, _ name: String) -> ExplorationMunicipality {
        ExplorationMunicipality(
            code: code, name: name, prefectureCode: String(code.prefix(2)),
            prefectureName: String(code.prefix(2)), isPrefecture: false
        )
    }
}

/// 都道府県・政令指定都市のカードの中身と共有文。
struct RegionShareCardContentTests {
    private let calculator = ExplorationProgressCalculator()
    private let date = Date(timeIntervalSince1970: 1_795_000_000)

    /// 愛知県の4市区町村(名古屋市の2区＋豊橋市・岡崎市)のうち3つを訪れた集計。
    private var aichi: ExplorationSummary {
        calculator.summarize(
            municipalities: [
                entry("23100", "名古屋市"), entry("23101", "名古屋市千種区"), entry("23102", "名古屋市東区"),
                entry("23201", "豊橋市"), entry("23202", "岡崎市"),
            ],
            visitedCodes: ["23101", "23201", "23202"]
        )
    }

    @Test func 都道府県のカードは市区町村の件数と制覇率と称号を載せる() throws {
        let prefecture = try #require(aichi.prefectures.first)

        let content = RegionShareCardContent(prefecture: prefecture, date: date)

        #expect(content.headline == "わたしの愛知県")
        #expect(content.visitedCount == 3)
        #expect(content.totalCount == 4)
        #expect(content.unit == "市区町村")
        #expect(content.achievementText == "75%達成")
        #expect(content.nextGoalText == "あと1市区町村で100%達成")
        #expect(content.visitedCodes == ["23101", "23201", "23202"])
    }

    @Test func 都道府県の共有文は件数と割合とApp_Storeのリンク() throws {
        let content = RegionShareCardContent(prefecture: try #require(aichi.prefectures.first), date: date)

        #expect(content.shareText == "愛知県の3/4市区町村を訪れました(\(content.percentageText)) #よりみち\nhttps://apps.apple.com/jp/app/id6805073599")
    }

    @Test func 政令指定都市のカードは区を単位に数え区だけを塗る() throws {
        let city = try #require(aichi.designatedCities.first)

        let content = RegionShareCardContent(city: city, date: date)

        #expect(content.headline == "名古屋市の区めぐり")
        #expect(content.visitedCount == 1)
        #expect(content.totalCount == 2)
        #expect(content.unit == "区")
        #expect(content.visitedCodes == ["23101"])
        #expect(content.shareText == "名古屋市の1/2区を訪れました(\(content.percentageText)) #よりみち\nhttps://apps.apple.com/jp/app/id6805073599")
    }

    @Test func 都道府県単独の記録だけなら0件とは書かずはじまりの文にする() throws {
        let summary = calculator.summarize(
            municipalities: [entry("23201", "豊橋市")], visitedCodes: [], explicitlyVisitedPrefectureCodes: ["23"]
        )

        let content = RegionShareCardContent(prefecture: try #require(summary.prefectures.first), date: date)

        #expect(content.shareText.hasPrefix("よりみちで愛知県の市区町村めぐりをはじめました #よりみち"))
    }

    @Test func シェアの候補は訪れたものだけを制覇率の高い順に並べる() {
        let summary = calculator.summarize(
            municipalities: [
                entry("23201", "豊橋市"), entry("23202", "岡崎市"),
                entry("37201", "高松市"),
                entry("13101", "千代田区"), entry("13102", "中央区"),
            ],
            visitedCodes: ["23201", "37201"]
        )

        let candidates = ShareScopeCandidates(summary: summary)

        // 香川(100%) → 愛知(50%)。東京は訪れていないので出さない。
        #expect(candidates.prefectures.map(\.code) == ["37", "23"])
        #expect(candidates.availableKinds == [.japan, .prefecture])
        // 開いた画面の県は、訪れていなくても候補に入れる。
        #expect(ShareScopeCandidates(summary: summary, including: .prefecture(code: "13")).prefectures.map(\.code) == ["37", "23", "13"])
    }

    private func entry(_ code: String, _ name: String) -> ExplorationMunicipality {
        ExplorationMunicipality(
            code: code, name: name, prefectureCode: String(code.prefix(2)),
            prefectureName: "愛知県", isPrefecture: false
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

        // 本物の地図(MapKitのスナップショット)はネットワークが要る。撮れなければ図形だけのカードになる。
        let snapshots = ShareMapSnapshotStore()
        for size in ShareCardSize.allCases {
            let key = ShareMapSnapshotStore.Key(id: "japan", box: size == .story ? .japanStory : .japanSquare)
            await snapshots.loadBackdropIfNeeded(for: key, map: maps.municipalityMap)
            let backdrop = snapshots.backdrop(for: key)
            for fill in ShareCardFill.allCases {
                let model = ShareCardModel(subject: .japan(content, fill: fill, maps: maps), size: size, backdrop: backdrop)
                let image = try #require(ShareCardRenderer.render(model)).image
                let data = try #require(image.pngData())
                #expect(image.size.width * image.scale == size.pixelSize.width)
                #expect(image.size.height * image.scale == size.pixelSize.height)
                try data.write(to: directory.appendingPathComponent("share-card-\(size.rawValue)-\(fill.rawValue).png"))
            }
        }
    }

    /// 架空の旅: 愛知県の市区町村の約55%、そのうち名古屋市は16区のうち10区。
    @Test(.enabled(if: outputDirectory != nil))
    func 都道府県と政令指定都市の見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let repository = BoundaryRepository.bundled()
        let manifest = try await repository.loadManifest()
        let boundaries = try await repository.boundaries(
            in: manifest.files(in: .municipalities, lod: 2, prefectureCode: "23"),
            pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 100_000)
        )
        // 「所属未定地」(末尾000)はマスタに無いので除く。マスタと同じく名古屋市そのものの行も足す。
        var entries = boundaries.filter { !$0.code.hasSuffix("000") }.map {
            ExplorationMunicipality(code: $0.code, name: $0.name, prefectureCode: "23", prefectureName: "愛知県", isPrefecture: false)
        }
        entries.append(ExplorationMunicipality(code: "23100", name: "名古屋市", prefectureCode: "23", prefectureName: "愛知県", isPrefecture: false))
        let wardCodes = entries.map(\.code).filter { $0.hasPrefix("231") && $0 != "23100" }.sorted()
        let otherCodes = entries.map(\.code).filter { !$0.hasPrefix("231") }.sorted()
        var visited = Set(wardCodes.prefix(10))
        let target = Int((Double(wardCodes.count + otherCodes.count) * 0.55).rounded(.up))
        visited.formUnion(otherCodes.enumerated().filter { $0.offset.isMultiple(of: 2) || $0.offset < 6 }.map(\.element).prefix(target - visited.count))
        let summary = ExplorationProgressCalculator().summarize(municipalities: entries, visitedCodes: visited)
        let prefecture = try #require(summary.prefectures.first)
        let city = try #require(summary.designatedCities.first)

        let store = SilhouetteMapStore()
        await store.loadSharePrefectureMapIfNeeded(code: "23")
        await store.loadShareDesignatedCityMapIfNeeded(cityCode: city.code, wardCodes: Set(city.wards.map(\.code)))
        let prefectureMap = try #require(store.sharePrefectureMaps["23"])
        let cityMap = try #require(store.shareDesignatedCityMaps[city.code])

        let cards: [(name: String, content: RegionShareCardContent, map: SilhouetteMap)] = [
            ("prefecture-aichi", RegionShareCardContent(prefecture: prefecture, date: .now), prefectureMap),
            ("city-nagoya", RegionShareCardContent(city: city, date: .now), cityMap),
        ]
        let snapshots = ShareMapSnapshotStore()
        for card in cards {
            for size in ShareCardSize.allCases {
                let key = ShareMapSnapshotStore.Key(id: card.name, box: size == .story ? .regionStory : .regionSquare)
                await snapshots.loadBackdropIfNeeded(for: key, map: card.map)
                let model = ShareCardModel(subject: .region(card.content, map: card.map), size: size, backdrop: snapshots.backdrop(for: key))
                let image = try #require(ShareCardRenderer.render(model)).image
                #expect(image.size.width * image.scale == size.pixelSize.width)
                let data = try #require(image.pngData())
                try data.write(to: directory.appendingPathComponent("share-card-\(card.name)-\(size.rawValue).png"))
            }
        }
    }
}
