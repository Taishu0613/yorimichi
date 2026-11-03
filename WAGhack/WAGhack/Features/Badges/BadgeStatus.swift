import Foundation

/// 画面に出すバッジ1種類の状態。今の進み具合(`BadgeProgress`)と、保存済みの獲得記録(`BadgeAchievement`)を合わせたもの。
/// 表示の文言はここで決め、画面は判定や文言の組み立てを個別に持たない。
struct BadgeStatus: Identifiable {
    let progress: BadgeProgress
    let achievement: BadgeAchievement?

    var id: BadgeID { definition.id }
    var definition: BadgeDefinition { progress.definition }
    var isAvailable: Bool { definition.isAvailable }
    var currentValue: Int { progress.value ?? 0 }

    /// 獲得した段階の数。記録を消して進み具合が下がっても、一度獲得した段階は保つ。
    var earnedTierCount: Int {
        max(progress.reachedTierCount, achievement?.tierCount ?? 0)
    }

    var isEarned: Bool { earnedTierCount > 0 }
    var isComplete: Bool { earnedTierCount >= definition.tiers.count }

    /// 段階式のバッジで獲得したランク。段階の無いバッジ・未獲得はnil。
    var rank: BadgeRank? {
        definition.isTiered ? BadgeRank(earnedTierCount: earnedTierCount) : nil
    }

    /// 次に目指す閾値。準備中・コンプリート済みはnil。
    var nextThreshold: Int? {
        guard isAvailable, !isComplete else { return nil }
        return definition.tiers[earnedTierCount]
    }

    var remaining: Int? {
        nextThreshold.map { max($0 - currentValue, 0) }
    }

    /// 次の閾値までの割合。コンプリート済みは1。
    var fractionToNext: Double {
        guard let nextThreshold, nextThreshold > 0 else { return isComplete ? 1 : 0 }
        return min(Double(currentValue) / Double(nextThreshold), 1)
    }

    /// 「7 / 10区」のような進み具合。
    var progressText: String? {
        guard let nextThreshold else { return nil }
        return "\(currentValue) / \(nextThreshold)\(definition.unit)"
    }

    /// 一覧のスタンプの下に添える一言。色だけに頼らず、文字でも獲得済みかどうかを伝える。
    var shortStatusText: String {
        guard isAvailable else { return "準備中" }
        if isComplete { return definition.isTiered ? "コンプリート" : "獲得済み" }
        if let rank { return rank.name }
        return progressText ?? ""
    }

    /// 詳細画面の、今どうなっていて次に何をすればよいかを1文で伝える見出し。
    var headline: String {
        guard isAvailable else { return "このバッジは準備中です" }
        if isComplete {
            return definition.isTiered ? "コンプリート！すべてのランクを達成しました" : "獲得済み！"
        }
        guard let remaining else { return "" }
        if currentValue == 0, !isEarned, definition.id == .firstStep {
            return "最初の街を訪れてみよう"
        }
        switch definition.criterion {
        case .sameNameGroups:
            if let group = partialGroup {
                return "\(group.name)をもう1つ訪れよう"
            }
        case .themeSpots:
            let rest = progress.themeSpots.filter { !$0.item.isVisited }.map(\.label)
            if !rest.isEmpty {
                return "残り：" + rest.joined(separator: "・")
            }
        case .nearbyMunicipalities:
            let cluster = progress.nearbyCluster
            if cluster.count == 2 {
                return "\(cluster[0].name)と\(cluster[1].name)の近くで、もう1つの街を記録しよう"
            }
            return "3つの街がぎゅっと集まる場所へ行こう"
        default:
            break
        }
        if let nextRank = BadgeRank(earnedTierCount: earnedTierCount + 1), definition.isTiered {
            return "あと\(remaining)\(definition.unit)で\(nextRank.name)"
        }
        return "あと\(remaining)\(definition.unit)で獲得"
    }

    /// 詳細の「地図で探す」の行き先と文言。まだ訪れていない対象を地図で探せるバッジだけが持つ。
    var mapTarget: (focus: BadgeMapFocus, title: String)? {
        guard isAvailable, !isComplete else { return nil }
        if case .themeSpots = definition.criterion,
           let next = progress.themeSpots.first(where: { !$0.item.isVisited }) {
            return (.municipality(code: next.item.code, prefectureCode: next.item.prefectureCode), "\(next.label)を地図で探す")
        }
        if case .nearbyMunicipalities = definition.criterion, let area = progress.nearbyArea {
            return (.area(area), "記録した場所のまわりを地図で見る")
        }
        if let area = definition.mapArea {
            return (.area(area), "地図で未訪問の\(definition.unit)を探す")
        }
        switch definition.criterion {
        case .municipalitiesInOnePrefecture:
            guard let top = progress.prefectureCounts.first else { return nil }
            return (.prefecture(code: top.code), "地図で\(top.name)を探検する")
        case .visitedAreas:
            guard let area = progress.groups.first(where: { !$0.isSatisfied })?.area else { return nil }
            return (.area(area), "地図で\(area.name)を探す")
        case .sameNameGroups:
            guard let next = partialGroup?.items.first(where: { !$0.isVisited }) else { return nil }
            return (
                .municipality(code: next.code, prefectureCode: next.prefectureCode),
                "地図で\(next.prefectureName)の\(next.name)を探す"
            )
        default:
            return nil
        }
    }

    /// 1つだけ訪れていて、まだ条件を満たしていないまとまり(ふたごのまちの片方だけ訪れた組)。
    private var partialGroup: BadgeChecklistGroup? {
        progress.groups.first { !$0.isSatisfied && $0.visitedCount > 0 }
    }

    /// 読み上げ用の状態。「獲得済み・シルバー」「未獲得・7 / 10区」のように、見た目の印影を言葉にする。
    var accessibilityStatus: String {
        guard isAvailable else { return "準備中" }
        var parts: [String] = [isEarned ? "獲得済み" : "未獲得"]
        if let rank { parts.append(rank.name) }
        if isComplete, definition.isTiered { parts.append("コンプリート") }
        if let progressText { parts.append(progressText) }
        return parts.joined(separator: "、")
    }
}

extension [BadgeStatus] {
    /// 一覧の「次のチャレンジ」。次の閾値に最も近いものを選び、同じなら残りの少ないもの、それも同じなら定義の順を優先する。
    var nextChallenge: BadgeStatus? {
        let candidates = filter { $0.nextThreshold != nil }
        return candidates.enumerated().min { lhs, rhs in
            let left = (-lhs.element.fractionToNext, lhs.element.remaining ?? .max, lhs.offset)
            let right = (-rhs.element.fractionToNext, rhs.element.remaining ?? .max, rhs.offset)
            return left < right
        }?.element
    }

    var earnedCount: Int { filter(\.isEarned).count }
}
