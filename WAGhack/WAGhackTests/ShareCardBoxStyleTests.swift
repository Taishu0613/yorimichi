import Foundation
import SwiftUI
import Testing
import UIKit
@testable import WAGhack

/// シェアのカードの箱の位置・見た目と、市区町村のシェア画面から切り替えられる範囲(1.8.0 (5))。
@MainActor
struct ShareCardBoxStyleTests {
    // MARK: - 箱の位置

    @Test func タップするたびに箱は上_真ん中_下_上の順に動く() {
        #expect(ShareCardBoxPosition.top.next == .middle)
        #expect(ShareCardBoxPosition.middle.next == .bottom)
        #expect(ShareCardBoxPosition.bottom.next == .top)
    }

    @Test func 三回タップすると元の位置に戻る() {
        for position in ShareCardBoxPosition.allCases {
            #expect(position.next.next.next == position)
        }
    }

    // MARK: - 箱の見た目

    @Test func 初めてシェアするときの箱はアプリの色() {
        #expect(ShareCardBoxStyle.defaultStyle == .app)
    }

    /// 選んだ見た目はUserDefaultsに`rawValue`で残る。値を変えると前回の選択が読めなくなる。
    @Test func 覚えておく見た目の値は変えない() {
        #expect(ShareCardBoxStyle.storageKey == "shareCardBoxStyle")
        #expect(ShareCardBoxStyle.allCases.map(\.rawValue) == ["app", "whiteLine", "blackLine"])
        #expect(ShareCardBoxStyle.allCases.map(\.title) == ["アプリの色", "白の線", "黒の線"])
    }

    @Test func 覚えていない値なら見た目は読めず既定に戻る() {
        // `@AppStorage`は`init(rawValue:)`がnilのとき既定値(`defaultStyle`)を使う。
        #expect(ShareCardBoxStyle(rawValue: "glass") == nil)
    }

    // MARK: - 市区町村のシェア画面の範囲

    private func prefecture(_ code: String, _ name: String) -> PrefectureExploration {
        PrefectureExploration(code: code, name: name, municipalities: [], visitedCodes: [], isExplicitlyVisited: false)
    }

    @Test func 街からはその県と全国に切り替えられる() {
        let options = TownShareScopeOption.options(
            townCode: "23100", prefectures: [prefecture("13", "東京都"), prefecture("23", "愛知県")]
        )
        #expect(options.map(\.title) == ["この街", "愛知県", "全国"])
        #expect(options.map(\.target) == [.town, .region(.prefecture(code: "23")), .region(.japan)])
    }

    @Test func 県の集計に無い街はこの街と全国だけ() {
        let options = TownShareScopeOption.options(townCode: "99999", prefectures: [prefecture("23", "愛知県")])
        #expect(options.map(\.target) == [.town, .region(.japan)])
    }

    @Test func 行政区域コードが5桁でなければ県を探さない() {
        let options = TownShareScopeOption.options(townCode: "23", prefectures: [prefecture("23", "愛知県")])
        #expect(options.map(\.target) == [.town, .region(.japan)])
    }
}

/// 1.8.0 (5)の見本の画像(写真を敷いた全国・愛知県・名古屋市のカード)を書き出す。ふだんのテストでは動かさない。
///
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardBoxStyleSampleRenderer ...`
/// 写真は`SHARE_CARD_SAMPLE_PHOTO`(画像のパス)で渡す。渡さなければ、空と山を描いた架空の写真を使う。
@MainActor
struct ShareCardBoxStyleSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func 写真を敷いたカードの見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let photo = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_PHOTO"].flatMap { UIImage(contentsOfFile: $0) } ?? Self.fakePhoto()

        // 全国: 架空の旅(東京23区・香川県すべて・札幌・京都など)を、箱の見た目3種類で。
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
            ExplorationMunicipality(code: $0.code, name: $0.name, prefectureCode: $0.prefectureCode, prefectureName: $0.prefectureCode, isPrefecture: false)
        }
        let codes = entries.map(\.code)
        var visited = Set(codes.filter { $0.hasPrefix("131") || $0.hasPrefix("37") })
        for (prefix, count) in [("011", 10), ("261", 11), ("401", 14), ("141", 18), ("272", 12), ("472", 8), ("042", 6), ("172", 5), ("23", 30)] {
            visited.formUnion(codes.filter { $0.hasPrefix(prefix) }.prefix(count))
        }
        let japan = ShareCardContent(summary: ExplorationProgressCalculator().summarize(municipalities: entries, visitedCodes: visited), date: .now)
        for style in ShareCardBoxStyle.allCases {
            for size in ShareCardSize.allCases {
                try write(
                    JapanStandardCard(content: japan, size: size, fill: .municipalities, maps: maps, photo: photo, boxStyle: style, boxPosition: .bottom),
                    size: size, name: "japan-photo-\(style.rawValue)", in: directory
                )
            }
        }

        // 愛知県: 市区町村の約半分を訪れた架空の記録。
        let aichiBoundaries = try await repository.boundaries(
            in: manifest.files(in: .municipalities, lod: 2, prefectureCode: "23"),
            pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 100_000)
        )
        let aichi = aichiBoundaries.filter { !$0.code.hasSuffix("000") }.map {
            ExplorationMunicipality(code: $0.code, name: $0.name, prefectureCode: "23", prefectureName: "愛知県", isPrefecture: false)
        }
        let aichiVisited = Set(aichi.map(\.code).sorted().enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
        let prefecture = try #require(ExplorationProgressCalculator().summarize(municipalities: aichi, visitedCodes: aichiVisited).prefectures.first)
        await store.loadSharePrefectureMapIfNeeded(code: "23")
        let aichiContent = RegionShareCardContent(prefecture: prefecture, date: .now)
        for size in ShareCardSize.allCases {
            try write(
                RegionStandardCard(content: aichiContent, size: size, map: store.sharePrefectureMaps["23"], photo: photo, boxStyle: .app, boxPosition: .top),
                size: size, name: "aichi-photo-app-top", in: directory
            )
        }

        // 名古屋市のみどころ: 白の線で、箱を上と下に。
        let nagoya = TriviaShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true,
            topic: .highlights("名古屋市は、愛知県の県庁所在地で、中部地方の中心となる大都市だ。1610年に徳川家康が名古屋城を築き、清須の町をまるごと移した「清須越し」で町ができた。久屋大通と若宮大通は、幅100mの広い道路だ。")
        )
        for position in [ShareCardBoxPosition.top, .bottom] {
            for size in ShareCardSize.allCases {
                try write(
                    TriviaStandardCard(
                        content: nagoya, size: size, map: nil, highlightedCodes: [], photo: photo, boxStyle: .whiteLine, boxPosition: position
                    ),
                    size: size, name: "nagoya-highlights-photo-whiteLine-\(position.rawValue)", in: directory
                )
            }
        }
    }

    /// 架空の写真。夕方の空・山・湖を描く(明るい空と暗い山の両方で、白と黒の箱の読みやすさを見るため)。
    private static func fakePhoto() -> UIImage {
        let size = ShareCardSize.story.pixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1), UIColor(red: 0.98, green: 0.78, blue: 0.55, alpha: 1)].map(\.cgColor)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height * 0.6), options: [.drawsAfterEndLocation])
            UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.62, y: size.height * 0.3, width: 160, height: 160))
            for (offset, shade) in [(0.0, 0.32), (0.18, 0.22)] {
                UIColor(red: shade * 0.6, green: shade, blue: shade * 0.9, alpha: 1).setFill()
                let path = UIBezierPath()
                let base = size.height * (0.6 + offset * 0.4)
                path.move(to: CGPoint(x: 0, y: base))
                path.addLine(to: CGPoint(x: size.width * 0.25, y: base - 260 + offset * 400))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: base - 80))
                path.addLine(to: CGPoint(x: size.width * 0.8, y: base - 330 + offset * 300))
                path.addLine(to: CGPoint(x: size.width, y: base - 60))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.close()
                path.fill()
            }
            UIColor(red: 0.2, green: 0.38, blue: 0.5, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.82, width: size.width, height: size.height * 0.18))
        }
    }

    private func write(_ view: some View, size: ShareCardSize, name: String, in directory: URL) throws {
        let image = try #require(ShareCardRenderer.render(view, size: size))
        #expect(image.size.width * image.scale == size.pixelSize.width)
        let data = try #require(image.pngData())
        try data.write(to: directory.appendingPathComponent("share-card-\(name)-\(size.rawValue).png"))
    }
}
