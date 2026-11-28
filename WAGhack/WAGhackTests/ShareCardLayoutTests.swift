import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import WAGhack

/// カードのレイアウトの選び方・都道府県の「全国の都道府県」・図鑑の入口の縮め方(1.8.0 (7))。
@MainActor
struct ShareCardLayoutTests {
    // MARK: - レイアウト

    @Test func どの種類も初めのレイアウトは選べるものに入っている() {
        for kind in [ShareCardSubjectKind.map, .firstVisit, .trivia] {
            #expect(kind.availableLayouts.contains(kind.defaultLayout))
        }
    }

    @Test func 覚えていないか選べないレイアウトは初めのレイアウトで描く() {
        #expect(ShareCardSubjectKind.map.resolvedLayout(nil) == .standard)
        #expect(ShareCardSubjectKind.trivia.resolvedLayout(.standard) == .standard)
    }

    @Test func レイアウトは地図のカードと街のカードで別々に覚える() {
        #expect(ShareCardSubjectKind.map.family == .map)
        #expect(ShareCardSubjectKind.firstVisit.family == .town)
        #expect(ShareCardSubjectKind.trivia.family == .town)
        #expect(ShareCardLayoutFamily.map.storageKey == "shareCardLayout.map")
        #expect(ShareCardLayoutFamily.town.storageKey == "shareCardLayout.town")
        #expect(ShareCardLayout.allCases.map(\.rawValue) == ["standard"])
    }

    @Test func 中身の種類は範囲とこの街のカードの種類で決まる() {
        #expect(selection(.town, townKind: .firstVisit).subjectKind == .firstVisit)
        #expect(selection(.town, townKind: .legend).subjectKind == .trivia)
        #expect(selection(.region(.prefecture(code: "23"))).subjectKind == .map)
    }

    // MARK: - 全国の都道府県

    @Test func 全国の都道府県は日本地図を読み込み県内の市区町村はその県の地図() {
        let nationwide = selection(.region(.prefecture(code: "23")), focus: .nationwide)
        #expect(nationwide.isNationwidePrefecture)
        #expect(nationwide.mapScope == .japan)
        let municipalities = selection(.region(.prefecture(code: "23")), focus: .municipalities)
        #expect(!municipalities.isNationwidePrefecture)
        #expect(municipalities.mapScope == .prefecture(code: "23"))
        // 都道府県でない範囲では、切り替えが残っていても全国の都道府県にしない。
        #expect(!selection(.region(.japan), focus: .nationwide).isNationwidePrefecture)
        #expect(selection(.town, focus: .nationwide).mapScope == nil)
    }

    @Test func 全国の都道府県は訪れた都道府県を数えてその県を強く示す() throws {
        let summary = makeSummary(visitedCodes: ["23101", "13101", "27102"])
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        let content = RegionShareCardContent(nationwide: aichi, summary: summary, date: .now)
        #expect(content.kind == .nationwidePrefecture)
        #expect(content.visitedCount == 3)
        #expect(content.totalCount == 4)
        #expect(content.visitedCodes == ["13", "23", "27"])
        #expect(content.emphasizedCodes == ["23"])
        #expect(content.headline == "愛知県に来た！")
        #expect(content.countCaption == "4都道府県中")
        #expect(content.primaryValueText == "3")
        #expect(content.secondaryValueText == "制覇率 \(content.percentageText)")
        #expect(content.shareText.hasPrefix("3/4都道府県を訪れました(愛知県も制覇) #よりみち\n"))
        #expect(content.shareText.hasSuffix(ShareCardContent.appStoreURL.absoluteString))
    }

    @Test func まだ訪れていない県は来たと書かず制覇とも書かない() throws {
        let summary = makeSummary(visitedCodes: ["13101"])
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        let content = RegionShareCardContent(nationwide: aichi, summary: summary, date: .now)
        #expect(content.headline == "次は愛知県へ")
        #expect(content.shareText.hasPrefix("1/4都道府県を訪れました #よりみち\n"))
    }

    @Test func 都道府県をどこも訪れていなければ旅のはじまりとして書く() throws {
        let summary = makeSummary(visitedCodes: [])
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        let content = RegionShareCardContent(nationwide: aichi, summary: summary, date: .now)
        #expect(content.shareText.hasPrefix("よりみちで都道府県めぐりをはじめました #よりみち\n"))
    }

    @Test func 県内の市区町村のカードはこれまでどおり制覇率が主役() throws {
        let summary = makeSummary(visitedCodes: ["23101"])
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        let content = RegionShareCardContent(prefecture: aichi, date: .now)
        #expect(content.emphasizedCodes.isEmpty)
        #expect(content.countCaption == "制覇率")
        #expect(content.primaryValueText == content.percentageText)
        #expect(content.secondaryValueText == "1 / 2 市区町村")
    }

    // MARK: - 図鑑の入口

    @Test func 街の写真の枠を越えるまでは文字付きで越えたら絵だけにする() {
        let threshold = MunicipalityShareEntryCollapse.threshold(hasHero: true, heroHeight: 172, topPadding: 16)
        #expect(threshold == 188)
        // 開いた直後は contentOffset.y == -contentInsets.top。
        #expect(!MunicipalityShareEntryCollapse.isCollapsed(contentOffsetY: -100, topInset: 100, threshold: threshold))
        #expect(!MunicipalityShareEntryCollapse.isCollapsed(contentOffsetY: 88, topInset: 100, threshold: threshold))
        #expect(MunicipalityShareEntryCollapse.isCollapsed(contentOffsetY: 89, topInset: 100, threshold: threshold))
    }

    @Test func 写真の無い画面は見出しを少し越えたら絵だけにする() {
        #expect(MunicipalityShareEntryCollapse.threshold(hasHero: false, heroHeight: 172, topPadding: 16) == 44)
    }

    // MARK: - 部品

    private func selection(
        _ target: ShareCardTarget, townKind: MunicipalityShareKind = .highlights, focus: PrefectureShareFocus = .municipalities
    ) -> ShareCardSelection {
        ShareCardSelection(target: target, townKind: townKind, spotIndex: 0, fill: .municipalities, prefectureFocus: focus)
    }

    /// 4都道府県(北海道・東京都・愛知県・大阪府)に2市区町村ずつの架空のマスタ。
    private func makeSummary(visitedCodes: Set<String>) -> ExplorationSummary {
        let prefectures = [("01", "北海道"), ("13", "東京都"), ("23", "愛知県"), ("27", "大阪府")]
        let municipalities = prefectures.flatMap { code, name in
            ["101", "102"].map { suffix in
                ExplorationMunicipality(code: code + suffix, name: "\(name)\(suffix)町", prefectureCode: code, prefectureName: name, isPrefecture: false)
            }
        }
        return ExplorationProgressCalculator().summarize(municipalities: municipalities, visitedCodes: visitedCodes)
    }
}

/// 1.8.0 (7)の見本の画像(愛知県の「全国の都道府県」のカード)を書き出す。ふだんのテストでは動かさない。
///
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardNationwideSampleRenderer ...`
/// 写真は`SHARE_CARD_SAMPLE_PHOTO`(画像のパス)で渡す。渡さなければ、空と海を描いた架空の写真を使う。
@MainActor
struct ShareCardNationwideSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func 全国の都道府県のカードの見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let photo = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_PHOTO"].flatMap { UIImage(contentsOfFile: $0) } ?? Self.fakePhoto()

        let store = SilhouetteMapStore()
        await store.loadShareCardMapsIfNeeded()
        let maps = try #require(store.shareCardMaps)
        let repository = BoundaryRepository.bundled()
        let manifest = try await repository.loadManifest()
        let all = try await repository.boundaries(
            in: manifest.files(in: .municipalities, lod: 0, intersecting: GeoBoundingBox(minLongitude: -180, minLatitude: -90, maxLongitude: 180, maxLatitude: 90)),
            pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 700_000)
        )
        let entries = all.map {
            ExplorationMunicipality(
                code: $0.code, name: $0.name, prefectureCode: $0.prefectureCode,
                prefectureName: $0.prefectureCode == "23" ? "愛知県" : $0.prefectureCode, isPrefecture: false
            )
        }
        // 架空の旅: 12都道府県(北海道・東京都・神奈川県・愛知県・京都府・大阪府など)を訪れた記録。
        let codes = entries.map(\.code)
        var visited: Set<String> = []
        for prefix in ["01", "04", "13", "14", "17", "22", "23", "26", "27", "37", "40", "47"] {
            visited.formUnion(codes.filter { $0.hasPrefix(prefix) }.prefix(3))
        }
        let summary = ExplorationProgressCalculator().summarize(municipalities: entries, visitedCodes: visited)
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        let content = RegionShareCardContent(nationwide: aichi, summary: summary, date: .now)

        let snapshots = ShareMapSnapshotStore()
        for size in ShareCardSize.allCases {
            let key = ShareMapSnapshotStore.Key(id: "japan", box: size == .story ? .regionStory : .regionSquare)
            await snapshots.loadBackdropIfNeeded(for: key, map: maps.municipalityMap)
            let subject = ShareCardSubject.region(content, map: maps.prefectureMap)
            try write(ShareCardModel(subject: subject, size: size, backdrop: snapshots.backdrop(for: key)), name: "aichi-nationwide", in: directory)
            try write(
                ShareCardModel(subject: subject, size: size, photo: photo, boxStyle: .whiteLine, boxPosition: .top),
                name: "aichi-nationwide-photo-whiteLine-top", in: directory
            )
        }
        try content.shareText.write(to: directory.appendingPathComponent("share-text-aichi-nationwide.txt"), atomically: true, encoding: .utf8)
    }

    /// 架空の写真。夕方の空と海(白の線の箱が読めるかを見るため、明るい空と暗い海の両方を入れる)。
    private static func fakePhoto() -> UIImage {
        let size = ShareCardSize.story.pixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor(red: 0.3, green: 0.5, blue: 0.82, alpha: 1), UIColor(red: 0.98, green: 0.76, blue: 0.52, alpha: 1)].map(\.cgColor)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height * 0.62), options: [.drawsAfterEndLocation])
            UIColor(red: 0.12, green: 0.3, blue: 0.42, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: size.height * 0.38))
        }
    }

    private func write(_ model: ShareCardModel, name: String, in directory: URL) throws {
        let image = try #require(ShareCardRenderer.render(model)).image
        #expect(image.size.width * image.scale == model.size.pixelSize.width)
        let data = try #require(image.pngData())
        try data.write(to: directory.appendingPathComponent("share-card-\(name)-\(model.size.rawValue).png"))
    }
}
