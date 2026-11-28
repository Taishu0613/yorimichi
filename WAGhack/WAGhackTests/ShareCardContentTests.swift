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
