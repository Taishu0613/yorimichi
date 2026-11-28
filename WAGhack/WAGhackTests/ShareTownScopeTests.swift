import Foundation
import SwiftUI
import Testing
import UIKit
@testable import WAGhack

/// 市区町村のシェア画面から切り替えられる範囲(1.8.0 (5))。
@MainActor
struct ShareTownScopeTests {
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
