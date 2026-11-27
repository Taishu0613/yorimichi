import SwiftData
import SwiftUI

/// 地図の画像をシェアする画面。範囲(全国・都道府県・政令指定都市)と形・塗りを選び、できた画像をそのまま確かめてから共有する。
///
/// 旅の記録・都道府県の画面・政令指定都市の画面・節目達成の知らせから開き、開いた場所に応じた範囲で始まる(`initialScope`)。
/// 集計は開いた場所から受け取らず、この画面で訪問記録から求める。どこから開いても同じ候補・同じ数字になるようにするため
/// (件数が変わらない限り`SavedPlacesStore`がキャッシュするので、範囲や形を変えても数え直さない)。
///
/// 地図の下には本物の地図(Appleマップのスナップショット)を薄く敷く(1.8.0 (3))。撮れるまでは図形だけのカードを出し、
/// 撮れたら描き直す。プレビューと共有する画像はいつも同じもの(`ShareCardSheetScaffold`)。
struct ShareMapSheet: View {
    /// 開いたときの範囲。
    let initialScope: ShareScope
    /// マップ画面から受け取る。プレビューなど渡されない場所では、この画面で作ったものを使う。
    let silhouetteStore: SilhouetteMapStore?

    @Query(sort: \Municipality.code) private var municipalities: [Municipality]
    @Query private var savedPlaces: [SavedPlace]
    @Query private var visitedPrefectures: [VisitedPrefecture]
    @State private var summaryStore = SavedPlacesStore()

    @State private var kind: ShareScopeKind
    /// 選んだ都道府県・政令指定都市。nilなら候補の先頭(制覇率が最も高いもの)を使う。
    @State private var prefectureCode: String?
    @State private var cityCode: String?
    @State private var layout: ShareCardLayout = .story
    @State private var fill: ShareCardFill = .municipalities
    /// 地図の読み込みを終えた範囲。読み込みに失敗した都道府県・政令指定都市も含む(地図なしのカードで描く)。
    @State private var loadedScopes: Set<ShareScope> = []
    /// 選んだ範囲・形・塗りで描いたカード。変えるたびに描き直す。
    @State private var rendered: RenderedShareCard?
    @State private var fallbackStore = SilhouetteMapStore()
    /// 地図の下に敷く本物の地図。この画面を開いている間だけ持つ。
    @State private var snapshotStore = ShareMapSnapshotStore()

    init(initialScope: ShareScope = .japan, silhouetteStore: SilhouetteMapStore?) {
        self.initialScope = initialScope
        self.silhouetteStore = silhouetteStore
        _kind = State(initialValue: initialScope.kind)
        if case .prefecture(let code) = initialScope { _prefectureCode = State(initialValue: code) }
        if case .designatedCity(let code) = initialScope { _cityCode = State(initialValue: code) }
    }

    private var store: SilhouetteMapStore { silhouetteStore ?? fallbackStore }

    var body: some View {
        let summary = summaryStore.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        let candidates = ShareScopeCandidates(summary: summary, including: initialScope)
        let scope = selectedScope(in: candidates)
        ShareCardSheetScaffold(
            navigationTitle: "地図をシェア",
            footnote: "画像には塗った地図と件数だけが入ります。ピン・住所・訪れた日時は入りません。",
            rendered: rendered,
            layout: $layout
        ) {
            scopePickers(candidates)
            // 塗りの単位を選べるのは全国だけ。都道府県・政令指定都市は区画がそのまま市区町村・区になる。
            if scope == .japan {
                ShareCardLabeledControl("塗り") {
                    Picker("塗り", selection: $fill) {
                        ForEach(ShareCardFill.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .task(id: scope) { await loadMap(for: scope, summary: summary) }
        // 地図ができたら、その範囲と形の本物の地図を撮る。
        .task(id: BackdropRequest(scope: scope, layout: layout, isMapReady: isMapReady(for: scope))) {
            guard let map = silhouetteMap(for: scope) else { return }
            await snapshotStore.loadBackdropIfNeeded(for: backdropKey(scope: scope, layout: layout), map: map)
        }
        // 地図の読み込みが終わったとき・本物の地図が届いたとき・範囲や形や塗りを変えたときに描き直す。
        .task(id: RenderKey(
            scope: scope, layout: layout, fill: fill, isMapReady: isMapReady(for: scope),
            hasBackdrop: snapshotStore.backdrop(for: backdropKey(scope: scope, layout: layout)) != nil
        )) {
            rendered = render(scope: scope, summary: summary)
        }
    }

    // MARK: - 範囲

    private func selectedScope(in candidates: ShareScopeCandidates) -> ShareScope {
        switch kind {
        case .japan:
            return .japan
        case .prefecture:
            guard let code = prefectureCode ?? candidates.prefectures.first?.code else { return .japan }
            return .prefecture(code: code)
        case .designatedCity:
            guard let code = cityCode ?? candidates.designatedCities.first?.code else { return .japan }
            return .designatedCity(code: code)
        }
    }

    @ViewBuilder
    private func scopePickers(_ candidates: ShareScopeCandidates) -> some View {
        let kinds = candidates.availableKinds
        // まだどこも訪れていないときは全国しか無いので、範囲の選択は出さない。
        if kinds.count > 1 {
            ShareCardLabeledControl("範囲") {
                Picker("範囲", selection: $kind) {
                    ForEach(kinds) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        switch kind {
        case .japan:
            EmptyView()
        case .prefecture:
            regionPicker(
                title: "都道府県",
                selection: Binding(get: { prefectureCode ?? candidates.prefectures.first?.code ?? "" }, set: { prefectureCode = $0 }),
                options: candidates.prefectures.map { ($0.code, "\($0.name)　\($0.progress.percentageText)") }
            )
        case .designatedCity:
            regionPicker(
                title: "政令指定都市",
                selection: Binding(get: { cityCode ?? candidates.designatedCities.first?.code ?? "" }, set: { cityCode = $0 }),
                options: candidates.designatedCities.map { ($0.code, "\($0.name)　\($0.progress.visited)/\($0.progress.total)区") }
            )
        }
    }

    /// どの都道府県・政令指定都市をシェアするか。候補は制覇率の高い順(`ShareScopeCandidates`)。
    private func regionPicker(title: String, selection: Binding<String>, options: [(code: String, label: String)]) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            Spacer(minLength: 8)
            Picker(title, selection: selection) {
                ForEach(options, id: \.code) { Text($0.label).tag($0.code) }
            }
            .pickerStyle(.menu)
            .tint(Pop.theme)
        }
    }

    // MARK: - 地図と描画

    /// 選んだ範囲の地図を用意する。読み込みを終えたら(失敗しても)`loadedScopes`に入れて描けるようにする。
    private func loadMap(for scope: ShareScope, summary: ExplorationSummary) async {
        switch scope {
        case .japan:
            await store.loadShareCardMapsIfNeeded()
        case .prefecture(let code):
            await store.loadSharePrefectureMapIfNeeded(code: code)
        case .designatedCity(let code):
            let wardCodes = summary.designatedCities.first { $0.code == code }.map { Set($0.wards.map(\.code)) } ?? []
            await store.loadShareDesignatedCityMapIfNeeded(cityCode: code, wardCodes: wardCodes)
        }
        // 範囲を切り替えて読み込みが取り消されたときは、まだ読み込んでいないので入れない。
        guard !Task.isCancelled else { return }
        loadedScopes.insert(scope)
    }

    /// 描いてよいか。地図ができたか、読み込みを終えた(失敗した)範囲なら描く。
    /// 地図の有無も見るのは、同じ地図を別の画面が読み込み中だとこの画面の読み込みがすぐ戻り、終わりを待てないため。
    private func isMapReady(for scope: ShareScope) -> Bool {
        if loadedScopes.contains(scope) { return true }
        switch scope {
        case .japan: return store.shareCardMaps != nil
        case .prefecture(let code): return store.sharePrefectureMaps[code] != nil
        case .designatedCity(let code): return store.shareDesignatedCityMaps[code] != nil
        }
    }

    private struct RenderKey: Hashable {
        let scope: ShareScope
        let layout: ShareCardLayout
        let fill: ShareCardFill
        let isMapReady: Bool
        let hasBackdrop: Bool
    }

    private struct BackdropRequest: Hashable {
        let scope: ShareScope
        let layout: ShareCardLayout
        let isMapReady: Bool
    }

    /// 本物の地図を重ねるシルエット。全国は2種類の地図が同じ枠なので、市区町村の地図で範囲を決める。
    private func silhouetteMap(for scope: ShareScope) -> SilhouetteMap? {
        switch scope {
        case .japan: store.shareCardMaps?.municipalityMap
        case .prefecture(let code): store.sharePrefectureMaps[code]
        case .designatedCity(let code): store.shareDesignatedCityMaps[code]
        }
    }

    /// 本物の地図は範囲とカードの地図の枠(形で変わる)ごとに撮る。
    private func backdropKey(scope: ShareScope, layout: ShareCardLayout) -> ShareMapSnapshotStore.Key {
        switch scope {
        case .japan:
            ShareMapSnapshotStore.Key(id: "japan", box: layout == .story ? .japanStory : .japanSquare)
        case .prefecture(let code):
            ShareMapSnapshotStore.Key(id: "prefecture-\(code)", box: layout == .story ? .regionStory : .regionSquare)
        case .designatedCity(let code):
            ShareMapSnapshotStore.Key(id: "city-\(code)", box: layout == .story ? .regionStory : .regionSquare)
        }
    }

    /// カードの日付は描いた時点の日にする(訪問日ではない)。
    private func render(scope: ShareScope, summary: ExplorationSummary) -> RenderedShareCard? {
        guard isMapReady(for: scope) else { return nil }
        let backdrop = snapshotStore.backdrop(for: backdropKey(scope: scope, layout: layout))
        switch scope {
        case .japan:
            // 全国の地図は読み込めないとカードの主役が無くなるので、地図ができるまでは描かない(1.8.0 (1)と同じ)。
            guard let maps = store.shareCardMaps else { return nil }
            let content = ShareCardContent(summary: summary, date: .now)
            return ShareCardRenderer.render(content: content, layout: layout, fill: fill, maps: maps, backdrop: backdrop)
                .map { RenderedShareCard(image: $0, message: content.shareText, title: "わたしの日本地図") }
        case .prefecture(let code):
            guard let prefecture = summary.prefectures.first(where: { $0.code == code }) else { return nil }
            let content = RegionShareCardContent(prefecture: prefecture, date: .now)
            return ShareCardRenderer.render(content: content, layout: layout, map: store.sharePrefectureMaps[code], backdrop: backdrop)
                .map { RenderedShareCard(image: $0, message: content.shareText, title: content.headline) }
        case .designatedCity(let code):
            guard let city = summary.designatedCities.first(where: { $0.code == code }) else { return nil }
            let content = RegionShareCardContent(city: city, date: .now)
            return ShareCardRenderer.render(content: content, layout: layout, map: store.shareDesignatedCityMaps[code], backdrop: backdrop)
                .map { RenderedShareCard(image: $0, message: content.shareText, title: content.headline) }
        }
    }
}
