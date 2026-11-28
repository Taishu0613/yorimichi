import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import WAGhack

/// カードのレイアウトの選び方・都道府県の「全国の都道府県」・図鑑の入口の縮め方(1.8.0 (7))。
@MainActor
struct ShareCardLayoutTests {
    // MARK: - レイアウト

    @Test func 種類ごとに選べるレイアウトと初めのレイアウト() {
        #expect(ShareCardSubjectKind.firstVisit.availableLayouts == [.photo, .photoMat, .sticker])
        #expect(ShareCardSubjectKind.trivia.availableLayouts == [.reading, .photo])
        #expect(ShareCardSubjectKind.map.availableLayouts == [.number, .map, .photo, .sticker])
        #expect(ShareCardSubjectKind.firstVisit.defaultLayout == .photo)
        #expect(ShareCardSubjectKind.trivia.defaultLayout == .reading)
        #expect(ShareCardSubjectKind.map.defaultLayout == .number)
    }

    @Test func 覚えていないか選べないレイアウトはその種類の初めのレイアウトで描く() {
        #expect(ShareCardSubjectKind.map.resolvedLayout(nil) == .number)
        // 豆知識で数字は選べない。
        #expect(ShareCardSubjectKind.trivia.resolvedLayout(.number) == .reading)
        // 初訪問で地図は選べない。
        #expect(ShareCardSubjectKind.firstVisit.resolvedLayout(.map) == .photo)
        #expect(ShareCardSubjectKind.map.resolvedLayout(.sticker) == .sticker)
    }

    @Test func レイアウトはカードの種類ごとに覚える() {
        #expect(ShareCardSubjectKind.map.family == .map)
        #expect(ShareCardSubjectKind.firstVisit.family == .firstVisit)
        #expect(ShareCardSubjectKind.trivia.family == .trivia)
        #expect(ShareCardLayoutFamily.allCases.map(\.storageKey) == ["shareCardLayout.map", "shareCardLayout.firstVisit", "shareCardLayout.trivia"])
        #expect(ShareCardLayout.allCases.map(\.rawValue) == ["photo", "photoMat", "sticker", "number", "map", "reading"])
    }

    @Test func ステッカーだけ透明で写真と形の選択を使わない() {
        for layout in ShareCardLayout.allCases {
            #expect(layout.isTransparent == (layout == .sticker))
            #expect(layout.usesPhoto == (layout != .sticker))
            #expect(layout.usesCardSize == (layout != .sticker))
        }
        // 帯を動かせるのはフォトだけ。
        #expect(ShareCardLayout.allCases.filter(\.canMoveBox) == [.photo])
    }

    @Test func 中身の種類は範囲とこの街のカードの種類で決まる() {
        #expect(selection(.town, townKind: .firstVisit).subjectKind == .firstVisit)
        #expect(selection(.town, townKind: .legend).subjectKind == .trivia)
        #expect(selection(.region(.prefecture(code: "23"))).subjectKind == .map)
    }

    @Test func フォトに載せる一文は本文の最初の文() {
        #expect(TriviaShareCardContent.firstSentence(of: " 名古屋市は大都市だ。城がある。") == "名古屋市は大都市だ。")
        #expect(TriviaShareCardContent.firstSentence(of: "句点が無い") == "句点が無い")
        let spot = TriviaShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true, topic: .spot(name: "名古屋城", line: "金の鯱を見る。"))
        #expect(spot.leadSentence == "「名古屋城」金の鯱を見る。")
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
        let stat = try #require(ShareCardSubject.region(content, map: nil).summary.stat)
        #expect(stat.value == "3/4")
        #expect(stat.detail == "制覇率 \(content.percentageText)")
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

    @Test func 県内の市区町村のカードは制覇率が主役() throws {
        let summary = makeSummary(visitedCodes: ["23101"])
        let aichi = try #require(summary.prefectures.first { $0.code == "23" })
        let content = RegionShareCardContent(prefecture: aichi, date: .now)
        #expect(content.emphasizedCodes.isEmpty)
        let stat = try #require(ShareCardSubject.region(content, map: nil).summary.stat)
        #expect(stat.value == content.percentageText)
        #expect(stat.caption == "制覇率")
        #expect(stat.detail == "1 / 2 市区町村")
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


/// 1.8.0 (7)のレイアウトの見本の画像を書き出す。ふだんのテストでは動かさない。
///
/// `TEST_RUNNER_SHARE_CARD_SAMPLE_DIR=/path/to/dir xcodebuild test -only-testing:WAGhackTests/ShareCardLayoutSampleRenderer ...`
/// 名古屋市(初訪問・みどころ・都市伝説・できること)・愛知県(県内の市区町村・全国の都道府県)・全国を、選べるレイアウトすべてで縦長に描く。
/// 写真は`SHARE_CARD_SAMPLE_PHOTO`(画像のパス)で渡す。渡さなければ、空と海を描いた架空の写真を使う。
@MainActor
struct ShareCardLayoutSampleRenderer {
    private static let outputDirectory = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_DIR"]

    @Test(.enabled(if: outputDirectory != nil))
    func どのレイアウトも見本の画像を書き出す() async throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let photo = ProcessInfo.processInfo.environment["SHARE_CARD_SAMPLE_PHOTO"].flatMap { UIImage(contentsOfFile: $0) } ?? Self.fakePhoto()

        let store = SilhouetteMapStore()
        let repository = BoundaryRepository.bundled()
        let manifest = try await repository.loadManifest()

        // 全国: 架空の旅(12都道府県、愛知県は市区町村の約半分)。
        await store.loadShareCardMapsIfNeeded()
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
        let nagoyaMap = try #require(nagoya.map(in: store))
        let nagoyaCodes = nagoya.highlightedCodes(in: nagoyaMap)

        let subjects: [(name: String, snapshotID: String, subject: ShareCardSubject)] = [
            ("japan", "japan", .japan(ShareCardContent(summary: summary, date: .now), fill: .municipalities, maps: maps)),
            ("aichi", "prefecture-23", .region(RegionShareCardContent(prefecture: aichiOnly, date: .now), map: store.sharePrefectureMaps["23"])),
            ("aichi-nationwide", "japan", .region(RegionShareCardContent(nationwide: aichi, summary: summary, date: .now), map: maps.prefectureMap)),
            ("nagoya-first-visit", nagoya.snapshotID, .firstVisit(
                FirstVisitShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 124, total: 1_918)),
                map: nagoyaMap, highlightedCodes: nagoyaCodes
            )),
            ("nagoya-highlights", nagoya.snapshotID, .trivia(Self.trivia(.highlights(Self.highlights)), map: nagoyaMap, highlightedCodes: nagoyaCodes)),
            ("nagoya-legend", nagoya.snapshotID, .trivia(Self.trivia(.legend(Self.legend)), map: nagoyaMap, highlightedCodes: nagoyaCodes)),
            ("nagoya-spots", nagoya.snapshotID, .trivia(
                Self.trivia(.spot(name: "名古屋城", line: "金の鯱がのる天守と、復元された本丸御殿の豪華なふすま絵を見られる。")),
                map: nagoyaMap, highlightedCodes: nagoyaCodes
            )),
        ]

        let snapshots = ShareMapSnapshotStore()
        // 縦長は`directory`に、正方形は`directory/square`に書き出す(ステッカーは形を選ばないので1枚)。
        let squareDirectory = directory.appendingPathComponent("square")
        try FileManager.default.createDirectory(at: squareDirectory, withIntermediateDirectories: true)
        for (name, snapshotID, subject) in subjects {
            for layout in subject.kind.availableLayouts {
                if layout == .sticker {
                    var model = ShareCardModel(subject: subject, layout: layout, size: .story, boxStyle: ShareCardBoxStyle.stickerDefaultStyle)
                    try writeSticker(model, name: "\(name)-sticker-whiteLine", in: directory)
                    model.boxStyle = .app
                    try writeSticker(model, name: "\(name)-sticker-app", in: directory)
                    continue
                }
                for size in ShareCardSize.allCases {
                    let output = size == .story ? directory : squareDirectory
                    var model = ShareCardModel(subject: subject, layout: layout, size: size)
                    // 写真なし(本物の地図を敷くレイアウトは地図を撮る)と、写真あり。
                    if let box = ShareCardMapBox.backdropBox(for: layout, size: size), let map = subject.mapForSnapshot {
                        let key = ShareMapSnapshotStore.Key(id: snapshotID, box: box)
                        await snapshots.loadBackdropIfNeeded(for: key, map: map)
                        model.backdrop = snapshots.backdrop(for: key)
                    }
                    try write(model, name: "\(name)-\(layout.rawValue)", in: output)
                    model.backdrop = nil
                    model.photo = photo
                    try write(model, name: "\(name)-\(layout.rawValue)-photo", in: output)
                    if layout == .photo {
                        model.boxStyle = .whiteLine
                        model.boxPosition = .top
                        try write(model, name: "\(name)-\(layout.rawValue)-photo-whiteLine-top", in: output)
                    }
                }
            }
        }
    }

    private static let highlights = "名古屋市は、愛知県の県庁所在地で、中部地方の中心となる大都市だ。1610年に徳川家康が名古屋城を築き、清須の町をまるごと移した「清須越し」で町ができた。久屋大通と若宮大通は、幅100mの広い道路だ。熱田神宮には、三種の神器の一つ、草薙剣が祀られている。人口は東京23区、横浜市、大阪市に次ぐ多さだ。"
    private static let legend = "名古屋城の天守の金鯱は、何度も盗難にあった。1876年には鱗3枚がはがされ、1937年には北の鯱の鱗58枚から金が盗まれた。江戸時代には、盗賊の柿木金助が大凧に乗って天守に近づき、鯱の鱗を盗んだという話が作られ、歌舞伎でも演じられた。"

    private static func trivia(_ topic: TriviaShareCardContent.Topic) -> TriviaShareCardContent {
        TriviaShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true, topic: topic)
    }

    /// 架空の写真。夕方の空と海と岬(白の線・黒の線の帯が読めるかを見るため、明るい空と暗い海の両方を入れる)。
    private static func fakePhoto() -> UIImage {
        let size = ShareCardSize.story.pixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.3, green: 0.5, blue: 0.82, alpha: 1), UIColor(red: 0.98, green: 0.76, blue: 0.52, alpha: 1)].map(\.cgColor)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height * 0.62), options: [.drawsAfterEndLocation])
            UIColor(red: 1, green: 0.93, blue: 0.75, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.6, y: size.height * 0.45, width: 170, height: 170))
            UIColor(red: 0.12, green: 0.3, blue: 0.42, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.6, width: size.width, height: size.height * 0.4))
            UIColor(red: 0.16, green: 0.22, blue: 0.2, alpha: 1).setFill()
            let cape = UIBezierPath()
            cape.move(to: CGPoint(x: 0, y: size.height * 0.5))
            cape.addCurve(to: CGPoint(x: size.width * 0.45, y: size.height * 0.62), controlPoint1: CGPoint(x: size.width * 0.2, y: size.height * 0.48), controlPoint2: CGPoint(x: size.width * 0.35, y: size.height * 0.58))
            cape.addLine(to: CGPoint(x: 0, y: size.height * 0.66))
            cape.close()
            cape.fill()
        }
    }

    private func write(_ model: ShareCardModel, name: String, in directory: URL) throws {
        let rendered = try #require(ShareCardRenderer.render(model))
        #expect(!rendered.isTransparent)
        #expect(rendered.image.size.width * rendered.image.scale == model.size.pixelSize.width)
        let data = try #require(rendered.image.pngData())
        try data.write(to: directory.appendingPathComponent("\(name)-\(model.size.rawValue).png"))
    }

    /// ステッカーは透明が残っているか(アルファがあり、左上の角が透明か)も確かめる。
    private func writeSticker(_ model: ShareCardModel, name: String, in directory: URL) throws {
        let rendered = try #require(ShareCardRenderer.render(model))
        #expect(rendered.isTransparent)
        let data = try #require(rendered.image.pngData())
        let url = directory.appendingPathComponent("\(name).png")
        try data.write(to: url)
        // 書き出したPNGを読み直して確かめる(共有するのもこのPNGのファイル)。
        let reloaded = try #require(UIImage(contentsOfFile: url.path)?.cgImage)
        #expect([.premultipliedLast, .premultipliedFirst, .last, .first].contains(reloaded.alphaInfo))
        #expect(Self.alpha(ofTopLeftPixelIn: reloaded) == 0)
        #expect(CGFloat(reloaded.width) == StickerCardLayout.width * ShareCardSize.renderScale)
    }

    private static func alpha(ofTopLeftPixelIn image: CGImage) -> UInt8 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        // 左上の1pxだけを1×1の枠に描く(CGの原点は左下なので、画像の上端が枠に来るようずらす)。
        context?.draw(image, in: CGRect(x: 0, y: -CGFloat(image.height - 1), width: CGFloat(image.width), height: CGFloat(image.height)))
        return pixel[3]
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
