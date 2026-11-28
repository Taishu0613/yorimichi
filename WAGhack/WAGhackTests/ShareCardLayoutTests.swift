import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import WAGhack

/// カードの箱の見た目・レイアウト・位置の調整・アプリ名の角・添える形・形の見せ方(1.8.0 (9)で(6)の箱に戻し、(10)で2つのレイアウトにした)、
/// 都道府県の「全国の都道府県」・図鑑の入口の縮め方(1.8.0 (7))。
@MainActor
struct ShareCardLayoutTests {
    // MARK: - 箱

    @Test func レイアウトは標準と小さい箱で初めは標準() {
        #expect(ShareCardBoxSize.defaultSize == .standard)
        #expect(ShareCardBoxSize.allCases.map(\.rawValue) == ["standard", "compact"])
        #expect(ShareCardBoxSize.allCases.map(\.title) == ["標準", "小さい箱"])
        #expect(Set([ShareCardBoxSize.storageKey, ShareCardBoxStyle.storageKey, ShareCardShapeMode.storageKey]).count == 3)
        #expect(ShareCardModel(subject: .trivia(trivia(.highlights("城がある。")), map: nil, highlightedCodes: []), size: .story).adjustment == .none)
    }

    /// 選んだ値はUserDefaultsに`rawValue`で残る。(5)(6)と同じキー・値にして、前に選んだ見た目を引き継ぐ。
    @Test func 箱の見た目と形の見せ方の初めの値と覚えておく値() {
        #expect(ShareCardBoxStyle.defaultStyle == .app)
        #expect(ShareCardBoxStyle.storageKey == "shareCardBoxStyle")
        #expect(ShareCardBoxStyle.allCases.map(\.rawValue) == ["app", "whiteLine", "blackLine"])
        #expect(ShareCardBoxStyle.allCases.map(\.title) == ["アプリの色", "白の線", "黒の線"])
        #expect(ShareCardShapeMode.defaultMode == .location)
        #expect(ShareCardShapeMode.allCases.map(\.rawValue) == ["shapeOnly", "location"])
        #expect(ShareCardShapeMode.location.title(isTown: true) == "県の中の位置")
        #expect(ShareCardShapeMode.location.title(isTown: false) == "日本の中の位置")
        #expect(ShareCardBoxStyle.storageKey != ShareCardShapeMode.storageKey)
    }

    @Test func 写真が無いときは箱をアプリの色で描く() {
        let card = ShareCardSubject.trivia(trivia(.highlights("城がある。")), map: nil, highlightedCodes: [])
        var model = ShareCardModel(subject: card, size: .story, boxStyle: .whiteLine)
        #expect(model.effectiveBoxStyle == .app)
        model.photo = UIImage()
        #expect(model.effectiveBoxStyle == .whiteLine)
    }

    @Test func 写真を敷いた街のカードは上に大きな形を描くので名前には形を添えない() {
        let photo = UIImage()
        let location = ShareCardShape(map: nil, filledCodes: ["23100"], outlineWidth: 0.5, placeholderSystemImage: "map.fill", isLocation: true)
        let firstVisitCard = ShareCardSubject.firstVisit(firstVisit(date: nil), map: nil, highlightedCodes: [])
        let triviaCard = ShareCardSubject.trivia(trivia(.highlights("城がある。")), map: nil, highlightedCodes: [])
        #expect(ShareCardModel(subject: firstVisitCard, size: .story, photo: photo, locationShape: location).boxShape == nil)
        #expect(ShareCardModel(subject: triviaCard, size: .story, photo: photo).boxShape == nil)
        // 大きく描く形は、県の中の位置を選んでいればその形、形だけならその街の形。
        #expect(ShareCardModel(subject: triviaCard, size: .story, photo: photo, locationShape: location).shape.isLocation)
        #expect(!ShareCardModel(subject: triviaCard, size: .story, photo: photo).shape.isLocation)
        // 写真が無いときは地図の枠に形を大きく描くので、形だけなら添えず、位置なら添える。
        #expect(ShareCardModel(subject: triviaCard, size: .story).boxShape == nil)
        #expect(ShareCardModel(subject: triviaCard, size: .story, locationShape: location).boxShape?.isLocation == true)
    }

    @Test func 小さい箱の初訪問は記録を1行にまとめて減らさない() throws {
        let date = try #require(Calendar(identifier: .gregorian).date(
            from: DateComponents(timeZone: TimeZone(identifier: "Asia/Tokyo"), year: 2026, month: 11, day: 28, hour: 9)
        ))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let content = FirstVisitShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 124, total: 1_918), firstVisitDate: date
        )
        #expect(content.compactSummaryText(timeZone: tokyo) == "初訪問 · 愛知県 · 2026.11.28 · 全国 \(124.formatted())/\(1_918.formatted()) (\(content.percentageText))")
        // 日付が分からないときは日付だけを省く。
        let noDate = FirstVisitShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 1, total: 2))
        #expect(noDate.compactSummaryText(timeZone: tokyo) == "初訪問 · 愛知県 · 全国 1/2 (\(noDate.percentageText))")
    }

    @Test func 位置を選んだときはどのカードにも位置の形を添える() {
        let location = ShareCardShape(map: nil, filledCodes: ["23"], outlineWidth: 0.5, placeholderSystemImage: "map.fill", isLocation: true)
        let summary = makeSummary(visitedCodes: ["23101"])
        let aichi = summary.prefectures.first { $0.code == "23" }!
        let regionCard = ShareCardSubject.region(RegionShareCardContent(prefecture: aichi, date: .now), map: nil)
        #expect(ShareCardModel(subject: regionCard, size: .story, locationShape: location).boxShape?.isLocation == true)
        #expect(ShareCardModel(subject: regionCard, size: .story, photo: UIImage(), locationShape: location).boxShape?.isLocation == true)
        // 形だけの制覇率のカードは、写真の上・地図の枠に塗った地図を大きく描くので添えない。
        #expect(ShareCardModel(subject: regionCard, size: .story, photo: UIImage()).boxShape == nil)
    }

    @Test func 写真が無いときの地図の枠はカードの種類で決まる() {
        #expect(selection(.town, townKind: .firstVisit).mapBoxKind == .firstVisit)
        #expect(selection(.town, townKind: .legend).mapBoxKind == .trivia)
        #expect(selection(.region(.japan)).mapBoxKind == .japan)
        #expect(selection(.region(.prefecture(code: "23")), focus: .nationwide).mapBoxKind == .region)
        #expect(ShareCardMapBox.box(for: .firstVisit, size: .story) == .firstVisitStory)
        #expect(ShareCardMapBox.box(for: .trivia, size: .square) == .triviaSquare)
    }

    @Test func 本文の文字は大きい順に試して小さくしすぎない() {
        let scales = TriviaShareCardView.textScales
        #expect(scales.first == 1)
        #expect(scales == scales.sorted(by: >))
        #expect((scales.last ?? 0) >= 0.6)
    }

    @Test func 形の見せ方は全国と全国の都道府県では選ばない() {
        #expect(selection(.town).canShowLocation)
        #expect(selection(.region(.prefecture(code: "23"))).canShowLocation)
        #expect(selection(.region(.designatedCity(code: "23100"))).canShowLocation)
        #expect(!selection(.region(.japan)).canShowLocation)
        #expect(!selection(.region(.prefecture(code: "23")), focus: .nationwide).canShowLocation)
    }

    @Test func 初めて訪れた日が分かるときだけ日付を載せる() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: TimeZone(identifier: "Asia/Tokyo"), year: 2026, month: 11, day: 8, hour: 9))!
        #expect(FirstVisitShareCardContent.dateText(for: date, timeZone: TimeZone(identifier: "Asia/Tokyo")!) == "2026.11.08")
        let withDate = ShareCardSubject.firstVisit(firstVisit(date: date), map: nil, highlightedCodes: []).summary
        #expect(withDate.firstVisitDateText?.hasPrefix("初めて訪れた日 2026.11.") == true)
        let withoutDate = ShareCardSubject.firstVisit(firstVisit(date: nil), map: nil, highlightedCodes: []).summary
        #expect(withoutDate.firstVisitDateText == nil)
        #expect(withoutDate.label == "初訪問")
    }

    @Test func 位置の調整はずらせる幅と大きさを範囲に収める() {
        let cardSize = ShareCardSize.story.pointSize
        let placement = ShareCardElementPlacement()
        let moved = placement.moved(by: CGSize(width: 36, height: -64), in: cardSize)
        #expect(moved.unitOffset == CGSize(width: 0.1, height: -0.1))
        #expect(moved.offset(in: cardSize) == CGSize(width: 36, height: -64))
        let far = placement.moved(by: CGSize(width: 10_000, height: -10_000), in: cardSize)
        #expect(far.unitOffset == CGSize(width: ShareCardElementPlacement.offsetLimit.width, height: -ShareCardElementPlacement.offsetLimit.height))
        #expect(placement.scaled(by: 10).scale == ShareCardElementPlacement.scaleRange.upperBound)
        #expect(placement.scaled(by: 0.01).scale == ShareCardElementPlacement.scaleRange.lowerBound)
        var adjustment = ShareCardAdjustment.none
        #expect(!adjustment.isAdjusted)
        adjustment[.shape] = moved
        #expect(adjustment.isAdjusted)
        #expect(adjustment.shape == moved)
        #expect(adjustment.box == ShareCardElementPlacement())
    }

    @Test func アプリ名はふだん右下で箱が重なるときだけ右上() {
        for size in ShareCardSize.allCases {
            let bottom = ShareCardAppMark.cornerFrame(.bottomTrailing, size: size)
            let top = ShareCardAppMark.cornerFrame(.topTrailing, size: size)
            // どちらもカードの右端から小さな余白だけあけた角。
            #expect(bottom.maxX == size.pointSize.width - ShareCardAppMark.margin(for: size))
            #expect(bottom.maxY == size.pointSize.height - ShareCardAppMark.margin(for: size))
            #expect(top.minY == ShareCardAppMark.margin(for: size))
            // レイアウトの位置の箱(並べる範囲の下端まで)は、右下のアプリ名に掛からない。
            let insets = ShareCardInsets.photoContent(size)
            let boxBottom = size.pointSize.height - insets.bottom
            let box = CGRect(x: insets.leading, y: boxBottom - 120, width: size.pointSize.width - insets.leading - insets.trailing, height: 120)
            #expect(ShareCardLogoCorner.corner(avoiding: box, bottomLogoFrame: bottom) == .bottomTrailing)
            // 箱を下へずらして重なったら右上。
            #expect(ShareCardLogoCorner.corner(avoiding: box.offsetBy(dx: 0, dy: 80), bottomLogoFrame: bottom) == .topTrailing)
        }
        #expect(ShareCardLogoCorner.corner(avoiding: nil, bottomLogoFrame: .zero) == .bottomTrailing)
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
        let summaryOfCard = ShareCardSubject.region(content, map: nil).summary
        let stat = try #require(summaryOfCard.stat)
        #expect(stat.value == content.percentageText)
        #expect(stat.detail == "3 / 4 都道府県")
        #expect(summaryOfCard.name == "愛知県に来た！")
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

    private func firstVisit(date: Date?) -> FirstVisitShareCardContent {
        FirstVisitShareCardContent(
            municipalityName: "名古屋市", prefectureName: "愛知県", progress: ExplorationCount(visited: 1, total: 2), firstVisitDate: date
        )
    }

    private func trivia(_ topic: TriviaShareCardContent.Topic) -> TriviaShareCardContent {
        TriviaShareCardContent(municipalityName: "名古屋市", prefectureName: "愛知県", isVisited: true, topic: topic)
    }

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


