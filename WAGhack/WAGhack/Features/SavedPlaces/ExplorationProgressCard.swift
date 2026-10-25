import SwiftUI

/// 踏破率の大きな表示。カードの枠は呼び出し側(旅の記録・都道府県の一覧)が地図と一緒に包む。
struct ExplorationProgressCard: View {
    let title: String
    let progress: ExplorationCount
    var unit: String = "市区町村"
    /// trueならプログレスバー上の主表示を「訪問数 / 総数」に、割合はサブ表示に回す。都道府県のように総数が少なく、実数の方が伝わりやすい場合に使う。
    var emphasizesCount: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            Text(emphasizesCount ? "\(progress.visited) / \(progress.total)　達成" : progress.percentageText)
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .foregroundStyle(Pop.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            PopProgressBar(fraction: progress.fraction)
                .accessibilityLabel("\(unit)踏破率")
            Text(emphasizesCount ? "\(progress.percentageText)訪問済み" : "\(progress.visited) / \(progress.total) \(unit)")
                .font(.subheadline)
                .foregroundStyle(Pop.muted)
            PopPill(text: progress.achievementText, systemImage: "seal.fill", fill: Pop.yellow)
            Text(progress.nextGoalText(unit: unit))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Pop.ink)
        }
    }
}

struct PrefectureExplorationRow: View {
    let prefecture: PrefectureExploration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(prefecture.name).font(.headline.weight(.heavy))
                    Spacer()
                    Text(prefecture.progress.percentageText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                VStack(alignment: .leading) {
                    Text(prefecture.name).font(.headline.weight(.heavy))
                    Text(prefecture.progress.percentageText)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(Pop.ink)
            PopProgressBar(fraction: prefecture.progress.fraction)
                .accessibilityLabel("市区町村踏破率")
            Text("\(prefecture.progress.visited) / \(prefecture.progress.total) 市区町村 · \(prefecture.progress.achievementText)")
                .font(.caption)
                .foregroundStyle(Pop.muted)
        }
    }
}
