import SwiftData
import SwiftUI

// バッジの遊び方そのものが見える、バッジごとの進み具合の見せ方。
// どれも判定はせず、`BadgeProgress`の結果を描くだけにする(判定は`BadgeRuleEvaluator`)。

extension EnvironmentValues {
    /// 今いる都道府県のコード。候補の街を並べるときに、近くの街を先に出すために使う。
    /// 市区町村ごとの位置は持っていないので、距離ではなく都道府県が同じかどうかで並べる。
    @Entry var badgeCurrentPrefectureCode: String? = nil
}

/// 対象の街1行。押すと「地図で探す」「街の情報を見る」を選べる。
/// 地図の無い場所(プレビュー)では地図の項目を出さない。
struct BadgeTownRow: View {
    let item: BadgeChecklistItem
    var showsPrefecture = false
    let showInfo: (BadgeChecklistItem) -> Void

    var body: some View {
        Menu {
            BadgeTownRowActions(item: item, showInfo: showInfo)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .foregroundStyle(item.isVisited ? Pop.ink : Pop.muted)
                        if showsPrefecture, !item.prefectureName.isEmpty {
                            Text(item.prefectureName)
                                .font(.caption)
                                .foregroundStyle(Pop.muted)
                        }
                    }
                    if let recordedAt = item.recordedAt {
                        Text("\(recordedAt.formatted(date: .abbreviated, time: .omitted))に記録")
                            .font(.caption2)
                            .foregroundStyle(Pop.muted)
                    }
                }
            } icon: {
                Image(systemName: item.isVisited ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isVisited ? Pop.theme : Pop.muted)
            }
            .font(.subheadline.weight(item.isVisited ? .bold : .regular))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsPrefecture ? "\(item.prefectureName)\(item.name)" : item.name)
        .accessibilityValue(item.isVisited ? "訪問済み" : "未訪問")
        .accessibilityHint("地図で探すか、街の情報を見られます")
    }
}

/// 候補の街を、今いる都道府県の街を先に、あとは地域順(行政区域コード順)に並べる。
private func sortedCandidates(_ items: [BadgeChecklistItem], currentPrefectureCode: String?) -> [BadgeChecklistItem] {
    items.enumerated().sorted { lhs, rhs in
        let left = lhs.element.prefectureCode == currentPrefectureCode ? 0 : 1
        let right = rhs.element.prefectureCode == currentPrefectureCode ? 0 : 1
        return (left, lhs.offset) < (right, rhs.offset)
    }.map(\.element)
}

// MARK: - 数字の旅人(コレクション型)

/// 数字のマス目。埋まった数字と残りの数字がひと目で分かり、マスを押すとその数字の街が下に出る。
struct BadgeNumeralCollectionSection: View {
    let numerals: [BadgeNumeralProgress]
    let showInfo: (BadgeChecklistItem) -> Void

    @Environment(\.showBadgeAreaOnMap) private var showBadgeAreaOnMap
    @Environment(\.badgeCurrentPrefectureCode) private var currentPrefectureCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 下に街を出している数字。最初はまだ集めていない最初の数字(全部集めていれば最初の数字)。
    @State private var selectedSymbol: String?

    private var selected: BadgeNumeralProgress? {
        numerals.first { $0.symbol == selectedSymbol }
            ?? numerals.first { !$0.isCollected }
            ?? numerals.first
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 3 : 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("集めた数字")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(numerals) { numeral in
                    tile(numeral)
                }
            }
            let rest = numerals.filter { !$0.isCollected }.map(\.symbol)
            if !rest.isEmpty {
                Text("残り：" + rest.joined(separator: "・"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.ink)
            }
            if let selected {
                selectedPanel(selected)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
    }

    private func tile(_ numeral: BadgeNumeralProgress) -> some View {
        let isSelected = numeral.symbol == selected?.symbol
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedSymbol = numeral.symbol }
        } label: {
            VStack(spacing: 2) {
                Text(numeral.symbol)
                    .font(.system(.title2, design: .serif, weight: .heavy))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Image(systemName: numeral.isCollected ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(numeral.isCollected ? Pop.inkOnAccent : Pop.muted)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                numeral.isCollected ? Pop.themeSoft : Pop.card,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Pop.theme : Pop.border, lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(numeral.symbol)
        .accessibilityValue(numeral.isCollected ? "集めた" : "まだ")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectedPanel(_ numeral: BadgeNumeralProgress) -> some View {
        let visited = numeral.items.filter(\.isVisited)
        let candidates = sortedCandidates(numeral.items.filter { !$0.isVisited }, currentPrefectureCode: currentPrefectureCode)
        VStack(alignment: .leading, spacing: 10) {
            if numeral.isCollected {
                Text("「\(numeral.symbol)」はここで集めました")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
                ForEach(visited) { item in
                    BadgeTownRow(item: item, showsPrefecture: true, showInfo: showInfo)
                }
            } else {
                Text("「\(numeral.symbol)」がつく街（\(candidates.count)か所）")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
                ForEach(candidates.prefix(6)) { item in
                    BadgeTownRow(item: item, showsPrefecture: true, showInfo: showInfo)
                }
                if candidates.count > 6 {
                    PopFootnote("ほかに\(candidates.count - 6)か所あります。今いる都道府県の街を先に出しています。")
                }
                if let first = candidates.first, let showBadgeAreaOnMap {
                    Button {
                        showBadgeAreaOnMap(.municipality(code: first.code, prefectureCode: first.prefectureCode))
                    } label: {
                        Label("「\(numeral.symbol)」がつく街を地図で探す", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .popPrimaryButton()
                }
            }
        }
        .padding(12)
        .background(Pop.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Pop.border, lineWidth: 1))
    }
}

// MARK: - 都会にこんにちは(テーマ訪問型)

/// 目的地ごとのカード。訪れた場所にはチェックと記録した日を、まだの場所はそのまま次の行き先として見せる。
/// 街の呼び名(池袋)の下に判定に使う区(豊島区)を必ず添え、どこを記録すればよいかと判定を一致させる。
struct BadgeThemeSpotSection: View {
    let spots: [BadgeThemeSpotProgress]
    let showInfo: (BadgeChecklistItem) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("めぐる場所")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                ForEach(spots) { spot in
                    card(spot)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .popCard()
    }

    private func card(_ spot: BadgeThemeSpotProgress) -> some View {
        let item = spot.item
        return Menu {
            BadgeTownRowActions(item: item, showInfo: showInfo)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.isVisited ? "checkmark.seal.fill" : "mappin.circle")
                    .font(.title2)
                    .foregroundStyle(item.isVisited ? Pop.theme : Pop.muted)
                Text(spot.label)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(Pop.muted)
                Text(item.recordedAt.map { $0.formatted(.dateTime.month().day()) } ?? (item.isVisited ? "訪問済み" : "まだ"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(item.isVisited ? Pop.ink : Pop.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                item.isVisited ? Pop.themeSoft.opacity(0.6) : Pop.card,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Pop.border, style: StrokeStyle(lineWidth: 1.5, dash: item.isVisited ? [] : [5, 4]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spot.label)、\(item.name)")
        .accessibilityValue(item.isVisited ? "訪問済み" : "未訪問")
    }
}

/// 街の行・カードに共通のメニュー項目。
struct BadgeTownRowActions: View {
    let item: BadgeChecklistItem
    let showInfo: (BadgeChecklistItem) -> Void

    @Environment(\.showBadgeAreaOnMap) private var showBadgeAreaOnMap

    var body: some View {
        if let showBadgeAreaOnMap {
            Button("地図で探す", systemImage: "map") {
                showBadgeAreaOnMap(.municipality(code: item.code, prefectureCode: item.prefectureCode))
            }
        }
        Button("街の情報を見る", systemImage: "info.circle") {
            showInfo(item)
        }
    }
}

// MARK: - 超・境目！・超超・境目！(地理・位置関係型)

/// 街が近くに集まる様子を、目標の数の点を結ぶ小さな図で見せる(3つなら三角形、4つなら四角形)。
/// 記録した場所が近い街の数だけ点が塗られる。獲得済みなら、獲得した時点の証跡(記録した場所)を見せる。
struct BadgeNearbySection: View {
    let cluster: [BadgeChecklistItem]
    let evidence: BadgeEvidence?
    let isEarned: Bool
    let targetCount: Int
    let maxDistanceMeters: Double

    var body: some View {
        VStack(spacing: 14) {
            BadgeNearbyDiagram(pointCount: targetCount, filledCount: isEarned ? targetCount : min(cluster.count, targetCount))
                .frame(width: 150, height: 130)
                .accessibilityHidden(true)
            Text("目標：\(targetCount)つの市区町村の記録した場所が、おたがい\(Int(maxDistanceMeters / 1_000))km以内")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Pop.ink)
                .multilineTextAlignment(.center)
            if let evidence, isEarned {
                VStack(alignment: .leading, spacing: 6) {
                    Text("達成した\(targetCount)つの街")
                        .font(.subheadline.weight(.heavy))
                    ForEach(evidence.places, id: \.code) { place in
                        Label(place.name, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(Pop.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if cluster.count >= 2 {
                Text("近くに集まっている記録：" + cluster.map(\.name).joined(separator: "・"))
                    .font(.subheadline)
                    .foregroundStyle(Pop.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .popCard()
    }
}

/// 正多角形の頂点に置いた点と、すべての点どうしを結ぶ線。塗った点どうしの線は実線、それ以外は点線にする。
private struct BadgeNearbyDiagram: View {
    let pointCount: Int
    let filledCount: Int

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 16
            // 3つなら頂点が上の三角形、4つなら辺が水平な四角形になるよう、最初の点の角度をずらす。
            let startAngle = pointCount == 4 ? -3 * Double.pi / 4 : -Double.pi / 2
            let points = (0..<pointCount).map { index in
                let angle = startAngle + 2 * Double.pi * Double(index) / Double(pointCount)
                return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            }
            let pairs = (0..<pointCount).flatMap { a in ((a + 1)..<pointCount).map { b in (a, b) } }
            for (a, b) in pairs {
                var path = Path()
                path.move(to: points[a])
                path.addLine(to: points[b])
                let isSolid = a < filledCount && b < filledCount
                context.stroke(
                    path, with: .color(isSolid ? Pop.theme : Pop.muted.opacity(0.5)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: isSolid ? [] : [5, 6])
                )
            }
            for (index, point) in points.enumerated() {
                let rect = CGRect(x: point.x - 14, y: point.y - 14, width: 28, height: 28)
                let isFilled = index < filledCount
                context.fill(Path(ellipseIn: rect), with: .color(isFilled ? Pop.theme : Pop.card))
                context.stroke(Path(ellipseIn: rect), with: .color(isFilled ? Pop.theme : Pop.muted), lineWidth: 2.5)
            }
        }
    }
}

// MARK: - 街の情報

/// 候補の街の情報(みどころ・豆知識)。バッジの対象はコードしか持たないので、ここでマスタから街を引いて既存の詳細画面を出す。
struct BadgeMunicipalityInfoScreen: View {
    let item: BadgeChecklistItem

    @Query private var municipalities: [Municipality]

    init(item: BadgeChecklistItem) {
        self.item = item
        let code = item.code
        _municipalities = Query(filter: #Predicate<Municipality> { $0.code == code })
    }

    var body: some View {
        MunicipalityDetailScreen(municipality: municipalities.first, fallbackName: item.name)
    }
}
