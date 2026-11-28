import Foundation
import Testing
@testable import WAGhack

/// シェアし終えた回数と、それで決まる「旅のおすそわけ」のバッジ(1.8.0 (6))。
@MainActor
struct ShareCompletionCounterTests {
    private func makeUserDefaults() throws -> UserDefaults {
        let name = "ShareCompletionCounterTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: name))
        userDefaults.removePersistentDomain(forName: name)
        return userDefaults
    }

    @Test func 共有を終えたときだけ回数を1つ増やす() throws {
        let userDefaults = try makeUserDefaults()
        ShareCompletionCounter.recordShareSheetResult(completed: true, in: userDefaults)
        ShareCompletionCounter.recordShareSheetResult(completed: false, in: userDefaults)
        ShareCompletionCounter.recordShareSheetResult(completed: true, in: userDefaults)
        #expect(userDefaults.integer(forKey: ShareCompletionCounter.storageKey) == 2)
    }

    @Test func まだシェアしていなければ0回から始まる() throws {
        let userDefaults = try makeUserDefaults()
        ShareCompletionCounter.recordShareSheetResult(completed: false, in: userDefaults)
        #expect(userDefaults.integer(forKey: ShareCompletionCounter.storageKey) == 0)
    }

    @Test func 旅のおすそわけは1回_5回_20回でランクが上がる() throws {
        let definition = try #require(BadgeCatalog.definition(for: .tripSharer))
        #expect(definition.tiers == [1, 5, 20])
        #expect(definition.conditionText(5) == "旅のカードを5回シェアする")

        let summary = ExplorationSummary(prefectures: [], eligibleCodes: [])
        let reached = [0, 1, 4, 5, 19, 20, 30].map { count in
            BadgeRuleEvaluator().evaluate(summary, completedShareCount: count, definitions: [definition]).first?.reachedTierCount
        }
        #expect(reached == [0, 1, 1, 2, 2, 3, 3])
    }
}
