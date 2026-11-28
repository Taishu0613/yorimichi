import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import WAGhack

/// 1.8.0 (9)のカード((6)の箱に戻した見た目)の見本の画像を書き出す。ふだんのテストでは動かさない。
///
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardSampleRenderer ...`
/// 名古屋市(初訪問・みどころ・都市伝説・できること)・愛知県(県内の市区町村・全国の都道府県)・全国を、
/// 写真あり(箱の見た目3種 × 箱の上/下)と写真なし(アプリの色)を縦長に描く。正方形(アプリの色)・「形だけ」・
/// 日付の無い初訪問・とても長いみどころ・ステッカーは一部だけ。
/// 写真はアプリと同じくWikipediaの名古屋城の写真(`WikipediaImageService.spotPhoto`)を使う。取れなければ`SHARE_CARD_SAMPLE_PHOTO`、
/// それも無ければ空と海を描いた架空の写真。
@MainActor
struct ShareCardSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    private struct Sample {
        let name: String
        let snapshotID: String
        let subject: ShareCardSubject
        let selection: ShareCardSelection
    }

    @Test(.enabled(if: outputDirectory != nil))
    func どのカードも見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        let squareDirectory = directory.appendingPathComponent("square")
        try FileManager.default.createDirectory(at: squareDirectory, withIntermediateDirectories: true)
        let photo = await Self.samplePhoto()

        let store = SilhouetteMapStore()
        let repository = BoundaryRepository.bundled()
        let manifest = try await repository.loadManifest()

        // 全国: 架空の旅(12都道府県、愛知県は市区町村の約半分)。
        await store.loadShareCardMapsIfNeeded()
        await store.loadJapanMapIfNeeded()
        let maps = try #require(store.shareCardMaps)
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
        let codes = entries.map(\.code)
        var visited: Set<String> = []
        for prefix in ["01", "04", "13", "14", "17", "22", "26", "27", "37", "40", "47"] {
            visited.formUnion(codes.filter { $0.hasPrefix(prefix) }.prefix(4))
        }
        let aichiCodes = codes.filter { $0.hasPrefix("23") }.sorted()
        visited.formUnion(aichiCodes.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
        let summary = ExplorationProgressCalculator().summarize(municipalities: entries, visitedCodes: visited)
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        await store.loadSharePrefectureMapIfNeeded(code: "23")

        // 愛知県(県内の市区町村)は県の地図の区画で数え直す(全国のLOD0には無い細かい区画があるため)。
        let aichiBoundaries = try await repository.boundaries(
            in: manifest.files(in: .municipalities, lod: 2, prefectureCode: "23"),
            pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 100_000)
        )
        let aichiEntries = aichiBoundaries.filter { !$0.code.hasSuffix("000") }.map {
            ExplorationMunicipality(code: $0.code, name: $0.name, prefectureCode: "23", prefectureName: "愛知県", isPrefecture: false)
        }
        let aichiVisited = Set(aichiEntries.map(\.code).sorted().enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
        let aichiOnly = try #require(
            ExplorationProgressCalculator().summarize(municipalities: aichiEntries, visitedCodes: aichiVisited).prefectures.first
        )

        // 名古屋市(区を集めた地図)。
        let wards = aichiBoundaries.map(\.code).filter { $0.hasPrefix("231") && $0 != "23100" }
        let nagoya = ShareMunicipalityTarget(code: "23100", name: "名古屋市", prefectureName: "愛知県", wardCodes: Set(wards))
        await nagoya.loadMap(in: store)
        await nagoya.loadLocationMap(in: store)
        let nagoyaMap = try #require(nagoya.map(in: store))
        let nagoyaCodes = nagoya.highlightedCodes(in: nagoyaMap)
        let townSubject = MunicipalityShareSubject(
            target: nagoya, isVisited: true, highlightsText: Self.highlights, legendText: Self.legend, spots: []
        )
        let factory = ShareCardSubjectFactory(store: store, townSubject: townSubject, loadedScopes: [], isTownMapLoaded: true)
        let firstVisitDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 12))

        func firstVisit(date: Date?) -> ShareCardSubject {
            .firstVisit(
                FirstVisitShareCardContent(
                    municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 124, total: 1_918),
                    firstVisitDate: date
                ),
                map: nagoyaMap, highlightedCodes: nagoyaCodes
            )
        }
        let town = selection(.town)
        let samples: [Sample] = [
            Sample(name: "nagoya-first-visit", snapshotID: nagoya.snapshotID, subject: firstVisit(date: firstVisitDate), selection: town),
            Sample(name: "nagoya-highlights", snapshotID: nagoya.snapshotID, subject: .trivia(Self.trivia(.highlights(Self.highlights)), map: nagoyaMap, highlightedCodes: nagoyaCodes), selection: town),
            Sample(name: "nagoya-legend", snapshotID: nagoya.snapshotID, subject: .trivia(Self.trivia(.legend(Self.legend)), map: nagoyaMap, highlightedCodes: nagoyaCodes), selection: town),
            Sample(name: "nagoya-spots", snapshotID: nagoya.snapshotID, subject: .trivia(
                Self.trivia(.spot(name: "名古屋城", line: "金の鯱がのる天守と、復元された本丸御殿の豪華なふすま絵を見られる。")),
                map: nagoyaMap, highlightedCodes: nagoyaCodes
            ), selection: town),
            Sample(
                name: "aichi", snapshotID: "prefecture-23",
                subject: .region(RegionShareCardContent(prefecture: aichiOnly, date: .now), map: store.sharePrefectureMaps["23"]),
                selection: selection(.region(.prefecture(code: "23")))
            ),
            Sample(
                name: "aichi-nationwide", snapshotID: "japan",
                subject: .region(RegionShareCardContent(nationwide: aichi, summary: summary, date: .now), map: maps.prefectureMap),
                selection: selection(.region(.prefecture(code: "23")), focus: .nationwide)
            ),
            Sample(
                name: "japan", snapshotID: "japan",
                subject: .japan(ShareCardContent(summary: summary, date: .now), fill: .municipalities, maps: maps),
                selection: selection(.region(.japan))
            ),
        ]

        let snapshots = ShareMapSnapshotStore()
        for sample in samples {
            let locationShape = factory.locationShape(for: sample.selection)
            #expect(sample.selection.canShowLocation == (locationShape != nil))
            for size in ShareCardSize.allCases {
                let output = size == .story ? directory : squareDirectory
                let key = ShareMapSnapshotStore.Key(id: sample.snapshotID, box: ShareCardMapBox.box(for: sample.subject.mapBoxKind, size: size))
                if let map = sample.subject.mapForSnapshot {
                    await snapshots.loadBackdropIfNeeded(for: key, map: map)
                }
                var model = ShareCardModel(subject: sample.subject, size: size, locationShape: locationShape)
                // 正方形は、初めの見た目(アプリの色・下)だけ。
                let styles = size == .story ? ShareCardBoxStyle.allCases : [.app]
                for style in styles {
                    model.boxStyle = style
                    // 写真あり: 箱の上と下。
                    model.photo = photo
                    model.backdrop = nil
                    let positions: [ShareCardBoxPosition] = size == .story ? [.top, .bottom] : [.bottom]
                    for position in positions {
                        model.boxPosition = position
                        try write(model, name: "\(sample.name)-photo-\(style.rawValue)-\(position.rawValue)", in: output)
                    }
                }
                // 写真なし: (6)と同じ並び(箱は動かさず、アプリの色で描く)。
                model.photo = nil
                model.boxStyle = .app
                model.boxPosition = .bottom
                model.backdrop = snapshots.backdrop(for: key)
                try write(model, name: "\(sample.name)-map", in: output)
                // 「形だけ」(その範囲だけの形)と比べる1枚。
                if locationShape != nil, size == .story {
                    let shapeOnly = ShareCardModel(subject: sample.subject, size: size, photo: photo)
                    try write(shapeOnly, name: "\(sample.name)-photo-app-bottom-shapeOnly", in: output)
                }
            }
        }

        // 初めて訪れた日が分からない(図鑑から開いた)初訪問。
        let noDate = ShareCardModel(subject: firstVisit(date: nil), size: .story, photo: photo, locationShape: factory.locationShape(for: town))
        try write(noDate, name: "nagoya-first-visit-nodate-photo-app-bottom", in: directory)

        // とても長いみどころ(箱が伸び、収まらない分だけ本文の文字を小さくして全文を入れる)。
        let longHighlights = ShareCardSubject.trivia(Self.trivia(.highlights(Self.highlights + Self.highlights)), map: nagoyaMap, highlightedCodes: nagoyaCodes)
        for size in ShareCardSize.allCases {
            var long = ShareCardModel(subject: longHighlights, size: size, photo: photo, locationShape: factory.locationShape(for: town))
            long.boxStyle = .whiteLine
            try write(long, name: "nagoya-highlights-long-photo-whiteLine-bottom", in: size == .story ? directory : squareDirectory)
        }

        // ステッカーを写真に貼った例(初訪問。位置と大きさは指で動かした後の想定)。
        let stickerDirectory = directory.appendingPathComponent("sticker")
        try FileManager.default.createDirectory(at: stickerDirectory, withIntermediateDirectories: true)
        let stickerModel = ShareCardModel(subject: samples[0].subject, size: .story, locationShape: factory.locationShape(for: town))
        let canvas = ShareStickerCanvas(
            photo: photo, summary: stickerModel.summary, shape: stickerModel.shape, boxStyle: .whiteLine, size: .story,
            placement: ShareStickerPlacement(unitCenter: CGPoint(x: 0.38, y: 0.7), scale: 0.9)
        )
        let image = try #require(ShareCardRenderer.render(canvas, size: .story))
        try #require(image.pngData()).write(to: stickerDirectory.appendingPathComponent("sticker-\(samples[0].name)-whiteLine-story.png"))
    }

    private static let highlights = "名古屋市は、愛知県の県庁所在地で、中部地方の中心となる大都市だ。1610年に徳川家康が名古屋城を築き、清須の町をまるごと移した「清須越し」で町ができた。久屋大通と若宮大通は、幅100mの広い道路だ。熱田神宮には、三種の神器の一つ、草薙剣が祀られている。人口は東京23区、横浜市、大阪市に次ぐ多さだ。"
    private static let legend = "名古屋城の天守の金鯱は、何度も盗難にあった。1876年には鱗3枚がはがされ、1937年には北の鯱の鱗58枚から金が盗まれた。江戸時代には、盗賊の柿木金助が大凧に乗って天守に近づき、鯱の鱗を盗んだという話が作られ、歌舞伎でも演じられた。"

    private static func trivia(_ topic: TriviaShareCardContent.Topic) -> TriviaShareCardContent {
        TriviaShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true, topic: topic)
    }

    private func selection(_ target: ShareCardTarget, focus: PrefectureShareFocus = .municipalities) -> ShareCardSelection {
        ShareCardSelection(target: target, townKind: .firstVisit, spotIndex: 0, fill: .municipalities, prefectureFocus: focus)
    }

    /// アプリの図鑑と同じく、Wikipediaから名古屋城の写真を取る。
    private static func samplePhoto() async -> UIImage {
        if let photo = await WikipediaImageService.shared.spotPhoto(spotName: "名古屋城", municipalityName: "名古屋市"),
           let (data, _) = try? await URLSession.shared.data(from: photo.imageURL),
           let image = UIImage(data: data) {
            return image
        }
        if let path = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_PHOTO"], let image = UIImage(contentsOfFile: path) {
            return image
        }
        return fakePhoto()
    }

    /// 架空の写真。夕方の空と海と岬(白い文字・黒い文字が読めるかを見るため、明るい空と暗い海の両方を入れる)。
    private static func fakePhoto() -> UIImage {
        let size = ShareCardSize.story.pixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.3, green: 0.5, blue: 0.82, alpha: 1), UIColor(red: 0.98, green: 0.76, blue: 0.52, alpha: 1)].map(\.cgColor)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height * 0.62), options: [.drawsAfterEndLocation])
            UIColor(red: 0.12, green: 0.3, blue: 0.42, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.6, width: size.width, height: size.height * 0.4))
        }
    }

    private func write(_ model: ShareCardModel, name: String, in directory: URL) throws {
        let rendered = try #require(ShareCardRenderer.render(model))
        #expect(rendered.image.size.width * rendered.image.scale == model.size.pixelSize.width)
        let data = try #require(rendered.image.pngData())
        try data.write(to: directory.appendingPathComponent("\(name)-\(model.size.rawValue).png"))
    }
}

private extension ShareCardSubject {
    /// 本物の地図を撮る範囲を決める地図。全国は2種類の地図が同じ枠なので、市区町村の地図で撮る(シェア画面と同じ)。
    var mapForSnapshot: SilhouetteMap? {
        switch self {
        case .japan(_, _, let maps): maps.municipalityMap
        case .region(_, let map): map
        case .firstVisit(_, let map, _): map
        case .trivia(_, let map, _): map
        }
    }
}
