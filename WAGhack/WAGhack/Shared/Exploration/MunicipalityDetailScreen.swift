import SwiftUI

/// 市区町村の図鑑の1ページ。RakugakiSNSと同じPOPな見た目(`Pop`)で、読みものの「みどころ」と
/// 「怪奇・都市伝説」を主役にする。行政区域コードのような事務的な情報は末尾に小さく置く。
struct MunicipalityDetailScreen: View {
    let municipality: Municipality?
    let fallbackName: String
    /// 政令指定都市そのものを開いたときの区の訪問状況。渡されたら区の一覧を出す。
    var designatedCity: DesignatedCityExploration? = nil

    /// マップのシート内でだけ渡される。プレビューなど渡されない場所では形を出さない。
    @Environment(SilhouetteMapStore.self) private var silhouetteStore: SilhouetteMapStore?

    /// 形を描く枠の高さ。
    private static let shapeHeight: CGFloat = 200
    /// 形の上下の余白。先頭の透明な領域もこの分を含めた高さにして、最初は形とカードが重ならないようにする。
    private static let shapeVerticalPadding: CGFloat = 16
    /// 画面の左右の余白。カードのずらした影が端で切れないよう、影の分も含めて広めに取る。
    private static let horizontalPadding: CGFloat = 20

    /// 背景に形を敷くか。Storeが渡されない場所(プレビューなど)や市区町村が不明なときは敷かない。
    /// 政令指定都市は境界データに市そのものの形が無い(区の形だけ)ので敷かない。
    private var showsShape: Bool {
        municipality?.code != nil && silhouetteStore != nil && designatedCity == nil
    }

    private var displayName: String {
        municipality?.municipalityName ?? fallbackName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let code = municipality?.code, showsShape {
                    // 形そのものは背景に固定して描き、ここには同じ高さの透明な領域だけを置く。
                    // スクロールするとこの領域が上へ抜け、下のカードが形の上に覆い被さっていく。
                    Color.clear
                        .frame(height: Self.shapeHeight + Self.shapeVerticalPadding * 2)
                        // 読み込みはこの領域に付ける(ScrollViewの外側に付けるより、表示される市区町村と対応が明確なため)。
                        .task { await silhouetteStore?.loadMunicipalityMapIfNeeded(code: code) }
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 24) {
                    header

                    if let designatedCity {
                        WardsCard(city: designatedCity)
                    }

                    TriviaCard(style: .highlights, content: municipality?.famousThingsTrivia ?? "")
                    TriviaCard(style: .legend, content: municipality?.historyTrivia ?? "")

                    if let code = municipality?.code, !code.isEmpty {
                        Text("行政区域コード \(code)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Pop.muted)
                            .frame(maxWidth: .infinity)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.top, showsShape ? 0 : 16)
            .padding(.bottom, 32)
        }
        .background(alignment: .top) {
            shapeBackground
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 都道府県のピルと、蛍光ペンを引いた市区町村名。
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let prefectureName = municipality?.prefectureName, !prefectureName.isEmpty {
                PopPill(text: prefectureName, systemImage: "mappin", fill: Pop.mint)
            }
            MarkerHeading(displayName, size: 32)
        }
        .accessibilityElement(children: .combine)
    }
}

extension MunicipalityDetailScreen {
    /// スクロールの後ろに固定する紙と市区町村の形。スクロールしても動かず、カードが上を流れていく。
    /// 形はステッカーのように、ミントの塗り・インクの縁取り・ずらした影で描く。
    private var shapeBackground: some View {
        ZStack(alignment: .top) {
            Pop.paper
                .ignoresSafeArea()
            if showsShape, let code = municipality?.code, let map = silhouetteStore?.municipalityMaps[code] {
                let shape = SilhouetteShape(rings: map.areas.flatMap(\.rings), aspectRatio: map.aspectRatio)
                ZStack {
                    shape.fill(Pop.ink, style: FillStyle(eoFill: true))
                        .offset(x: 4, y: 4)
                    shape.fill(Pop.mint, style: FillStyle(eoFill: true))
                    shape.stroke(Pop.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                // 太い線と影が枠の端で切れないよう、内側に収める。
                .padding(6)
                .frame(height: Self.shapeHeight)
                .padding(.horizontal, 32)
                .padding(.vertical, Self.shapeVerticalPadding)
                .accessibilityHidden(true)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.3), value: municipality.flatMap { silhouetteStore?.municipalityMaps[$0.code] } != nil)
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

        /// みどころは明るい紙のカード、怪奇・都市伝説は夜色のカードにして、読む前から雰囲気を分ける。
        var cardFill: Color {
            switch self {
            case .highlights: Pop.card
            case .legend: Pop.night
            }
        }

        var shadow: Color {
            switch self {
            case .highlights: Pop.yellow
            case .legend: Pop.purple
            }
        }

        var marker: Color {
            switch self {
            case .highlights: Pop.yellow
            case .legend: Pop.purple
            }
        }

        /// 紫の丸の上では濃い字が読みにくいので、怪奇・都市伝説だけアイコンを明るい色にする。
        var iconForeground: Color {
            switch self {
            case .highlights: Pop.inkOnAccent
            case .legend: Pop.onNight
            }
        }

        var text: Color {
            switch self {
            case .highlights: Pop.ink
            case .legend: Pop.onNight
            }
        }
    }

    let style: Style
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PopIconBadge(systemImage: style.systemImage, fill: style.shadow, foreground: style.iconForeground)
                MarkerHeading(style.title, marker: style.marker, foreground: style.text)
            }
            // マスタが空欄の場合も「情報なし」へ置き換えず、空欄のまま表示する。
            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(style.text)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .topLeading)
                .textSelection(.enabled)
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
                PopIconBadge(systemImage: city.isComplete ? "crown.fill" : "building.columns.fill", fill: Pop.mint)
                MarkerHeading("区めぐり", marker: Pop.mint)
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
        .popCard(shadow: Pop.mint)
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
        .background(isVisited ? Pop.mint : Color.clear, in: shape)
        .overlay {
            if isVisited {
                shape.stroke(Pop.ink, lineWidth: Pop.borderWidth)
            } else {
                shape.stroke(Pop.muted, style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isVisited ? "訪問済み" : "未訪問")
    }
}
