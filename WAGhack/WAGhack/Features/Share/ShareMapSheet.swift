import SwiftData
import SwiftUI

/// 地図の画像をシェアする画面。範囲(全国・都道府県・政令指定都市)と形・塗りを選び、できた画像をそのまま確かめてから共有する。
///
/// 旅の記録・都道府県の画面・政令指定都市の画面・節目達成の知らせから開き、開いた場所に応じた範囲で始まる(`initialScope`)。
/// 集計は開いた場所から受け取らず、この画面で訪問記録から求める。どこから開いても同じ候補・同じ数字になるようにするため
/// (件数が変わらない限り`SavedPlacesStore`がキャッシュするので、範囲や形を変えても数え直さない)。
///
/// プレビューには共有するのと同じ画像(`ShareCardRenderer`の結果)を縮めて出す。
/// 画面用に別のViewを組むと、書き出した画像と見た目がずれることがあるため。
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
    @State private var rendered: RenderedCard?
    @State private var fallbackStore = SilhouetteMapStore()
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    preview
                    VStack(alignment: .leading, spacing: 14) {
                        scopePickers(candidates)
                        labeled("形") {
                            Picker("形", selection: $layout) {
                                ForEach(ShareCardLayout.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                        // 塗りの単位を選べるのは全国だけ。都道府県・政令指定都市は区画がそのまま市区町村・区になる。
                        if scope == .japan {
                            labeled("塗り") {
                                Picker("塗り", selection: $fill) {
                                    ForEach(ShareCardFill.allCases) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                    PopFootnote("画像には塗った地図と件数だけが入ります。ピン・住所・訪れた日時は入りません。")
                    shareButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Pop.paper.ignoresSafeArea())
            .navigationTitle("地図をシェア")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task(id: scope) { await loadMap(for: scope, summary: summary) }
        // 地図の読み込みが終わったとき・範囲や形や塗りを変えたときに描き直す。
        .task(id: RenderKey(scope: scope, layout: layout, fill: fill, isMapReady: isMapReady(for: scope))) {
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
            labeled("範囲") {
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
    }

    /// 共有するカード。画像と、一緒に共有する文・共有シートの見出し。
    private struct RenderedCard {
        let image: UIImage
        let message: String
        let title: String
    }

    /// カードの日付は描いた時点の日にする(訪問日ではない)。
    private func render(scope: ShareScope, summary: ExplorationSummary) -> RenderedCard? {
        guard isMapReady(for: scope) else { return nil }
        switch scope {
        case .japan:
            // 全国の地図は読み込めないとカードの主役が無くなるので、地図ができるまでは描かない(1.8.0 (1)と同じ)。
            guard let maps = store.shareCardMaps else { return nil }
            let content = ShareCardContent(summary: summary, date: .now)
            return ShareCardRenderer.render(content: content, layout: layout, fill: fill, maps: maps)
                .map { RenderedCard(image: $0, message: content.shareText, title: "わたしの日本地図") }
        case .prefecture(let code):
            guard let prefecture = summary.prefectures.first(where: { $0.code == code }) else { return nil }
            let content = RegionShareCardContent(prefecture: prefecture, date: .now)
            return ShareCardRenderer.render(content: content, layout: layout, map: store.sharePrefectureMaps[code])
                .map { RenderedCard(image: $0, message: content.shareText, title: content.headline) }
        case .designatedCity(let code):
            guard let city = summary.designatedCities.first(where: { $0.code == code }) else { return nil }
            let content = RegionShareCardContent(city: city, date: .now)
            return ShareCardRenderer.render(content: content, layout: layout, map: store.shareDesignatedCityMaps[code])
                .map { RenderedCard(image: $0, message: content.shareText, title: content.headline) }
        }
    }

    // MARK: - 画面の部品

    /// 縦長でも画面に収まるよう高さを抑え、形の違いは縦横比で見せる。
    private var preview: some View {
        let size = layout.pixelSize
        return Group {
            if let rendered {
                Image(uiImage: rendered.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Pop.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .accessibilityLabel("シェアする画像のプレビュー")
            } else {
                ProgressView("地図を準備しています")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Pop.themeTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .frame(maxHeight: 440)
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: layout)
    }

    private func labeled(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            picker()
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let rendered {
            ShareLink(
                item: ShareCardImage(image: rendered.image),
                message: Text(rendered.message),
                preview: SharePreview(rendered.title, image: Image(uiImage: rendered.image))
            ) {
                Label("シェアする", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .popPrimaryButton()
        } else {
            // 画像ができるまでは押せない同じ形のボタンを置き、読み込み後にレイアウトが跳ねないようにする。
            Button {} label: {
                Label("シェアする", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .popPrimaryButton()
            .disabled(true)
        }
    }
}
