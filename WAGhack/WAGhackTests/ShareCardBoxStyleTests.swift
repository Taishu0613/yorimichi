import Foundation
import SwiftUI
import Testing
import UIKit
@testable import WAGhack

/// シェアのカードの箱の位置・見た目と、市区町村のシェア画面から切り替えられる範囲(1.8.0 (5))。
@MainActor
struct ShareCardBoxStyleTests {
    // MARK: - 箱の位置

    @Test func タップするたびにフォトの帯は上と下を入れ替える() {
        #expect(ShareCardBoxPosition.top.next == .bottom)
        #expect(ShareCardBoxPosition.bottom.next == .top)
        #expect(ShareCardBoxPosition.allCases == [.top, .bottom])
    }

    // MARK: - 箱の見た目

    @Test func 初めてシェアするときの箱はアプリの色でステッカーは白の線() {
        #expect(ShareCardBoxStyle.defaultStyle == .app)
        #expect(ShareCardBoxStyle.stickerDefaultStyle == .whiteLine)
        #expect(ShareCardBoxStyle.storageKey != ShareCardBoxStyle.stickerStorageKey)
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
