import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import WAGhack

/// カードのまとまり・文字の色・形の見せ方・ステッカー(1.8.0 (8))、都道府県の「全国の都道府県」・図鑑の入口の縮め方(1.8.0 (7))。
@MainActor
struct ShareCardLayoutTests {
    // MARK: - まとまり

    @Test func まとまりの大きさはカードの種類で決まる() {
        #expect(ShareCardSubject.firstVisit(firstVisit(date: nil), map: nil, highlightedCodes: []).panelSize == .small)
        #expect(ShareCardSubject.trivia(trivia(.highlights("城がある。")), map: nil, highlightedCodes: []).panelSize == .large)
        let summary = makeSummary(visitedCodes: ["23101"])
        let aichi = summary.prefectures.first { $0.code == "23" }!
        #expect(ShareCardSubject.region(RegionShareCardContent(prefecture: aichi, date: .now), map: nil).panelSize == .medium)
    }

    @Test func アプリ名はまとまりと重ならない右の角に置く() {
        // 小さなまとまり(左に寄せる)は同じ側の右の角。
        #expect(ShareCardPanelSize.small.logoCorner(for: .bottom) == .bottomTrailing)
        #expect(ShareCardPanelSize.small.logoCorner(for: .top) == .topTrailing)
        // 横幅いっぱいのまとまりは反対側の右の角。
        #expect(ShareCardPanelSize.medium.logoCorner(for: .bottom) == .topTrailing)
        #expect(ShareCardPanelSize.large.logoCorner(for: .top) == .bottomTrailing)
    }

    @Test func タップするたびにまとまりは上と下を入れ替える() {
        #expect(ShareCardPanelPosition.top.next == .bottom)
        #expect(ShareCardPanelPosition.bottom.next == .top)
    }

    /// 選んだ値はUserDefaultsに`rawValue`で残る。値を変えると前回の選択が読めなくなる。
    @Test func 文字の色と形の見せ方の初めの値と覚えておく値() {
        #expect(ShareCardTextStyle.defaultStyle == .light)
        #expect(ShareCardTextStyle.allCases.map(\.rawValue) == ["light", "dark", "theme"])
        #expect(ShareCardTextStyle.allCases.map(\.title) == ["白い文字", "黒い文字", "アプリの色"])
        #expect(ShareCardShapeMode.defaultMode == .location)
        #expect(ShareCardShapeMode.allCases.map(\.rawValue) == ["shapeOnly", "location"])
        #expect(ShareCardShapeMode.location.title(isTown: true) == "県の中の位置")
        #expect(ShareCardShapeMode.location.title(isTown: false) == "日本の中の位置")
        #expect(ShareCardTextStyle.storageKey != ShareCardShapeMode.storageKey)
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

    @Test func 本文は収まる分だけ文を足す() {
        let text = "名古屋市は大都市だ。城がある。熱田神宮もある。"
        #expect(TriviaShareCardContent.excerpt(of: text, maxLength: 15) == "名古屋市は大都市だ。城がある。")
        #expect(TriviaShareCardContent.excerpt(of: text, maxLength: 100) == text)
        // 最初の文が長くても、最初の文は残す(残りは描く側が行数で切る)。
        #expect(TriviaShareCardContent.excerpt(of: text, maxLength: 3) == "名古屋市は大都市だ。")
        #expect(TriviaShareCardContent.excerpt(of: "句点が無い", maxLength: 3) == "句点が無い")
        let spot = trivia(.spot(name: "名古屋城", line: "金の鯱を見る。"))
        #expect(spot.excerpt(maxLength: 3) == "金の鯱を見る。")
    }

    @Test func ステッカーの位置はカードの外に出さず大きさは範囲に収める() {
        let cardSize = ShareCardSize.story.pointSize
        let placement = ShareStickerPlacement(unitCenter: CGPoint(x: 0.5, y: 0.5), scale: 1)
        let moved = placement.moved(by: CGSize(width: 1_000, height: -1_000), in: cardSize)
        #expect(moved.unitCenter == CGPoint(x: 1, y: 0))
        #expect(placement.scaled(by: 10).scale == ShareStickerPlacement.scaleRange.upperBound)
        #expect(placement.scaled(by: 0.01).scale == ShareStickerPlacement.scaleRange.lowerBound)
        // ステッカーが下半分ならアプリ名は右上、上半分なら右下。
        #expect(ShareStickerPlacement(unitCenter: CGPoint(x: 0.3, y: 0.8)).logoCorner(in: cardSize) == .topTrailing)
        #expect(ShareStickerPlacement(unitCenter: CGPoint(x: 0.3, y: 0.2)).logoCorner(in: cardSize) == .bottomTrailing)
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


