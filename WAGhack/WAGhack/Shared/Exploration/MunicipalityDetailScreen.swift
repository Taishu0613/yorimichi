import SwiftData
import SwiftUI

/// 市区町村の図鑑の1ページ。「その街の小さな旅行ガイド」として、街の写真→この街でできること→
/// 読みものの「みどころ」「怪奇・都市伝説」の順に並べる。見た目はRakugakiSNSと同じPOPな見た目(`Pop`)。
/// 行政区域コードのような事務的な情報は末尾に小さく置く。
///
/// 未訪問でも写真・スポット・豆知識を見られる。訪問の記録や地図の塗りは、ここからは変えない
/// (スポットを押したときはAppleマップ・Googleマップを開くだけ)。地図画面に依存しないので、どこから開いても同じ画面になる。
struct MunicipalityDetailScreen: View {
    let municipality: Municipality?
    let fallbackName: String
    /// 政令指定都市そのものを開いたときの区の訪問状況。渡されたら区の一覧を出す。
    var designatedCity: DesignatedCityExploration? = nil

    /// マップのシート内でだけ渡される。プレビューなど渡されない場所では形を出さない。
    @Environment(SilhouetteMapStore.self) private var silhouetteStore: SilhouetteMapStore?
    @Query private var savedPlaces: [SavedPlace]
    @State private var viewModel = MunicipalityDetailViewModel()

    /// 画面の左右の余白。カードのずらした影が端で切れないよう、影の分も含めて広めに取る。
    private static let horizontalPadding: CGFloat = 20

    private var displayName: String {
        municipality?.municipalityName ?? fallbackName
    }

    /// 形を描く市区町村のコード。政令指定都市は境界データに市そのものの形が無い(区の形だけ)ので描かない。
    private var silhouetteCode: String? {
        guard designatedCity == nil, silhouetteStore != nil else { return nil }
        return municipality?.code
    }

    /// 写真・スポットを探す対象。市区町村が分からない(住所だけの記録)ときは探さない。
    private var target: MunicipalityDetailTarget? {
        guard let municipality else { return nil }
        return MunicipalityDetailTarget(
            code: municipality.code,
            areaCodes: designatedCity.map { $0.wards.map(\.code) } ?? [municipality.code],
            prefectureName: municipality.prefectureName,
            municipalityName: municipality.municipalityName
        )
    }

    private var isVisited: Bool {
        if let designatedCity { return designatedCity.isVisited }
        guard let code = municipality?.code else { return false }
        return savedPlaces.contains { $0.municipality?.code == code }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if target != nil {
                    MunicipalityHeroView(
                        photo: viewModel.heroPhoto,
                        silhouette: silhouetteCode.flatMap { silhouetteStore?.municipalityMaps[$0] }
                    )
                    .animation(.spring(duration: 0.35, bounce: 0.3), value: silhouetteCode.flatMap { silhouetteStore?.municipalityMaps[$0] } != nil)
                }

                header

                if target != nil {
                    YorimichiSpotSection(state: viewModel.spotState, photos: viewModel.spotPhotos)
                }

                TriviaCard(style: .highlights, content: municipality?.famousThingsTrivia ?? "")
                TriviaCard(style: .legend, content: municipality?.historyTrivia ?? "")

                if let designatedCity {
                    WardsCard(city: designatedCity)
                }

                let photos = viewModel.displayedPhotos
                if !photos.isEmpty {
                    PhotoCreditsCard(photos: photos)
                }

                if let code = municipality?.code, !code.isEmpty {
                    Text("行政区域コード \(code)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Pop.muted)
                        .frame(maxWidth: .infinity)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Pop.paper.ignoresSafeArea())
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: silhouetteCode) {
            guard let silhouetteCode else { return }
            await silhouetteStore?.loadMunicipalityMapIfNeeded(code: silhouetteCode)
        }
        .task(id: target) {
            guard let target else { return }
            await viewModel.load(target)
        }
    }

    /// 都道府県のピル、蛍光ペンを引いた市区町村名、訪問の状態。
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let prefectureName = municipality?.prefectureName, !prefectureName.isEmpty {
                    PopPill(text: prefectureName, systemImage: "mappin", fill: Pop.themeSoft)
                }
                // 地図が主役なので、状態は押せない小さなピルで示すだけにする。
                if isVisited {
                    PopPill(text: "訪問済み", systemImage: "checkmark", fill: Pop.yellow)
                } else {
                    // ピルの文字は常に濃い色なので、ダークモードでも明るいままの色で塗る。
                    PopPill(text: "まだ訪れていない", systemImage: "circle.dashed", fill: Pop.onNight)
                }
            }
            MarkerHeading(displayName, size: 32)
        }
        .accessibilityElement(children: .combine)
    }
}

/// みどころ・怪奇・都市伝説の読みものカード。
private struct TriviaCard: View {
    enum Style {
        case highlights
        case legend

        var title: String {
            switch self {
            case .highlights: "みどころ"
            case .legend: "怪奇・都市伝説"
            }
        }

        var systemImage: String {
            switch self {
            case .highlights: "sparkles"
            case .legend: "moon.stars.fill"
            }
        }

        /// みどころは白いカード、怪奇・都市伝説は夜色のカードにして、読む前から雰囲気を分ける。
        var cardFill: Color {
            switch self {
            case .highlights: Pop.card
            case .legend: Pop.night
            }
        }

        var shadow: Color {
            switch self {
            case .highlights: Pop.yellow.opacity(0.7)
            case .legend: Pop.legend.opacity(0.6)
            }
        }

        var text: Color {
            switch self {
            case .highlights: Pop.ink
            case .legend: Pop.onNight
            }
        }

        var iconFill: Color {
            switch self {
            case .highlights: Pop.yellow
            case .legend: Pop.legend
            }
        }

        var marker: Color {
            switch self {
            case .highlights: Pop.yellow
            case .legend: Pop.legend
            }
        }

        /// 藍色の丸の上では濃い字が読みにくいので、怪奇・都市伝説だけアイコンを白にする。
        var iconForeground: Color {
            switch self {
            case .highlights: Pop.inkOnAccent
            case .legend: .white
            }
        }
    }

    let style: Style
    let content: String

    @State private var isExpanded = false

    /// 閉じているときに見せる行数。スポットより下に読みものが続くので、最初は短く見せて全文は開いて読む。
    private static let collapsedLineLimit = 5
    /// これより短い文章は、閉じても数行に収まるので「続きを読む」を出さない。
    /// 実際に行が切れるかを測るほどの精度は要らないため、文字数で決める。
    private static let collapsibleLength = 110

    private var isCollapsible: Bool {
        content.count > Self.collapsibleLength
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PopIconBadge(systemImage: style.systemImage, fill: style.iconFill, foreground: style.iconForeground)
                MarkerHeading(style.title, marker: style.marker, foreground: style.text)
            }
            // マスタが空欄の場合も「情報なし」へ置き換えず、空欄のまま表示する。元の文章は書き換えず、行数だけを絞る。
            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(style.text)
                .lineLimit(isCollapsible && !isExpanded ? Self.collapsedLineLimit : nil)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .topLeading)
                .textSelection(.enabled)
            if isCollapsible {
                Button {
                    isExpanded.toggle()
                } label: {
                    Label(isExpanded ? "閉じる" : "続きを読む", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(style.text)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .popCard(fill: style.cardFill, shadow: style.shadow)
        .accessibilityElement(children: .contain)
    }
}

/// 政令指定都市の区の訪問状況。訪れた区はミントのピル、まだの区は点線のピルで並べる。
private struct WardsCard: View {
    let city: DesignatedCityExploration

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PopIconBadge(systemImage: city.isComplete ? "crown.fill" : "building.columns.fill", fill: Pop.themeSoft)
                MarkerHeading("区めぐり", marker: Pop.themeSoft)
                Spacer(minLength: 8)
                PopPill(text: "\(city.progress.visited) / \(city.progress.total) 区", fill: Pop.yellow)
                    .monospacedDigit()
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(city.wards) { ward in
                    WardChip(name: ward.name, isVisited: city.visitedWardCodes.contains(ward.code))
                }
            }
        }
        .padding(18)
        .popCard()
        .accessibilityElement(children: .contain)
    }
}

private struct WardChip: View {
    let name: String
    let isVisited: Bool

    var body: some View {
        let shape = Capsule()
        HStack(spacing: 4) {
            Image(systemName: isVisited ? "checkmark" : "circle.dashed")
                .font(.caption2.weight(.heavy))
                .accessibilityHidden(true)
            Text(name)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(isVisited ? Pop.inkOnAccent : Pop.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isVisited ? Pop.themeSoft : Color.clear, in: shape)
        .overlay {
            if isVisited {
                shape.stroke(Pop.border, lineWidth: Pop.borderWidth)
            } else {
                shape.stroke(Pop.muted, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isVisited ? "訪問済み" : "未訪問")
    }
}
