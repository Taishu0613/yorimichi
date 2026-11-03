import Foundation

/// 獲得済みのバッジについて、訪問記録からは求め直せない分だけを保存する。
/// 進み具合は保存せず毎回求める(`BadgeProgress`)。ここに持つのは、一度獲得した状態を記録の削除で失わないための
/// 最高到達ランク・獲得日時・演出を見せたかどうか、だけ。
nonisolated struct BadgeAchievement: Codable, Equatable {
    /// 到達した段階の数(1始まり)。記録を消して進み具合が下がっても減らさない。
    var tierCount: Int
    /// 最初の段階を獲得した日時。導入前の訪問ですでに獲得していた分は、いつ条件を満たしたか分からないのでnil。
    var achievedAt: Date?
    /// 今の最高段階に上がった日時。nilの意味は`achievedAt`と同じ。
    var tierAchievedAt: Date?
    /// 獲得の演出で見せ終えた段階の数。`tierCount`より小さければ、まだ見せていない獲得がある。
    var announcedTierCount: Int
}

/// 獲得記録の全体。端末に1つのJSONとして保存する(`BadgeStore`)。
nonisolated struct BadgeLedger: Codable, Equatable {
    /// キーは`BadgeID`の生の値。将来バッジが増減しても読み込みが壊れないよう、enumではなく文字列で持つ。
    var achievements: [String: BadgeAchievement] = [:]
    /// 既存の訪問履歴をはじめて評価し終えたか。終えるまでに見つかった獲得は「新しく獲得した」として演出しない。
    var hasCompletedInitialSync = false
    /// はじめての評価で見つかった獲得の種類数。1種類以上あれば、まとめて1回だけ知らせる。見せたらnilにする。
    var pendingInitialSummaryCount: Int?

    func achievement(for id: BadgeID) -> BadgeAchievement? {
        achievements[id.rawValue]
    }
}

/// 新しく獲得した(または段階が上がった)バッジ1件。
nonisolated struct BadgeUnlock: Equatable, Identifiable {
    let id: BadgeID
    let tierCount: Int
}

/// 地図の上に出す、獲得の知らせ。
nonisolated enum BadgeAnnouncement: Equatable {
    /// 導入前の訪問履歴で、すでに獲得していたバッジのまとめ。
    case initialSummary(earnedCount: Int)
    /// 新しい訪問で獲得したバッジ。同時に複数獲得したらまとめて1回で見せる。
    case newlyEarned([BadgeUnlock])
}

/// 進み具合と保存済みの獲得記録を突き合わせ、獲得記録を更新する。副作用を持たないので単独で検証できる。
struct BadgeAchievementReconciler {
    func reconcile(_ ledger: BadgeLedger, with progresses: [BadgeProgress], now: Date) -> BadgeLedger {
        var updated = ledger
        let isInitialSync = !ledger.hasCompletedInitialSync
        for progress in progresses {
            let reached = progress.reachedTierCount
            let key = progress.definition.id.rawValue
            let current = updated.achievements[key]
            guard reached > (current?.tierCount ?? 0) else { continue }
            // はじめての評価で見つかった獲得は、導入前の訪問によるものなので日時を確定できない。
            let date: Date? = isInitialSync ? nil : now
            updated.achievements[key] = BadgeAchievement(
                tierCount: reached,
                achievedAt: current.map(\.achievedAt) ?? date,
                tierAchievedAt: date,
                // はじめての評価の分は1件ずつの演出をせず、まとめの知らせに任せる。
                announcedTierCount: isInitialSync ? reached : (current?.announcedTierCount ?? 0)
            )
        }
        if isInitialSync {
            updated.hasCompletedInitialSync = true
            let earnedCount = updated.achievements.values.filter { $0.tierCount > 0 }.count
            if earnedCount > 0 {
                updated.pendingInitialSummaryCount = earnedCount
            }
        }
        return updated
    }

    /// まだ見せていない知らせ。はじめての評価のまとめを先に見せる。
    func pendingAnnouncement(in ledger: BadgeLedger) -> BadgeAnnouncement? {
        if let count = ledger.pendingInitialSummaryCount {
            return .initialSummary(earnedCount: count)
        }
        // 表示順をコレクション帳と同じにするため、定義の順に並べる。
        let unlocks = BadgeID.allCases.compactMap { id -> BadgeUnlock? in
            guard let achievement = ledger.achievement(for: id),
                  achievement.tierCount > achievement.announcedTierCount else { return nil }
            return BadgeUnlock(id: id, tierCount: achievement.tierCount)
        }
        return unlocks.isEmpty ? nil : .newlyEarned(unlocks)
    }

    func markAnnounced(_ announcement: BadgeAnnouncement, in ledger: BadgeLedger) -> BadgeLedger {
        var updated = ledger
        switch announcement {
        case .initialSummary:
            updated.pendingInitialSummaryCount = nil
        case .newlyEarned(let unlocks):
            for unlock in unlocks {
                // 見せている間にさらに段階が上がった分は、次の知らせとして残す。
                updated.achievements[unlock.id.rawValue]?.announcedTierCount = unlock.tierCount
            }
        }
        return updated
    }
}
