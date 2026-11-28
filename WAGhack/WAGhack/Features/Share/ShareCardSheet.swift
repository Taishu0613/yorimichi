import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import os

/// シェア画面をどこから開いたか。開いた場所で、上の切り替え(範囲)の選択肢が変わる。
enum ShareCardSheetEntry {
    /// 旅の記録・都道府県の画面・政令指定都市の画面・節目達成の知らせから。範囲は全国・都道府県・政令指定都市。
    case region(ShareScope)
    /// 市区町村(図鑑の各見出し・図鑑のツールバー・初訪問のお祝い)から。範囲は「この街 / その県 / 全国」。
    /// `initialKind`は押した入口の種類。出せない種類なら、出せる最初の種類で開く。
    case town(MunicipalityShareSubject, initialKind: MunicipalityShareKind?)
}

/// 地図・市区町村のカードをシェアする画面(1.8.0 (5)で地図のシェアと市区町村のシェアを1つにした)。
///
/// - 範囲: 市区町村から開いたら「この街 / 愛知県 / 全国」、それ以外から開いたら「全国 / 都道府県 / 政令指定都市」。
///   どこから開いても同じ画面・同じ選択肢(写真・箱の見た目・形)で、範囲を変えても写真と箱の位置はそのまま残す。
/// - この街: 初訪問・みどころ・都市伝説・この街でできることをセグメントで切り替える。
/// - 写真: どのカードにも敷ける。写真があるときは本物の地図(Appleマップのスナップショット)を撮らない(ロゴも出ない)。
///   写真の上の箱はプレビューをタップするたびに上→真ん中→下と動かせる。
/// - 箱の見た目: アプリの色・白の線・黒の線。最後に選んだものを覚えておく(`ShareCardBoxStyle.storageKey`)。
///
/// 集計は開いた場所から受け取らず、この画面で訪問記録から求める。どこから開いても同じ候補・同じ数字になるようにするため
/// (件数が変わらない限り`SavedPlacesStore`がキャッシュするので、範囲や形を変えても数え直さない)。
/// プレビューと共有する画像はいつも同じもの(`ShareCardSheetScaffold`)。
struct ShareCardSheet: View {
    let entry: ShareCardSheetEntry
    /// マップ画面から受け取る。渡されなければ環境のもの、それも無ければこの画面で作ったものを使う。
    let silhouetteStore: SilhouetteMapStore?

    @Environment(SilhouetteMapStore.self) private var environmentStore: SilhouetteMapStore?
    @Query(sort: \Municipality.code) private var municipalities: [Municipality]
    @Query private var savedPlaces: [SavedPlace]
    @Query private var visitedPrefectures: [VisitedPrefecture]
    @State private var summaryStore = SavedPlacesStore()
    @State private var fallbackStore = SilhouetteMapStore()
    /// 地図の下に敷く本物の地図。この画面を開いている間だけ持つ。
    @State private var snapshotStore = ShareMapSnapshotStore()

    // MARK: 範囲

    /// 市区町村から開いたときに「この街」を選んでいるか。
    @State private var isTownSelected: Bool
    @State private var regionKind: ShareScopeKind
    /// 選んだ都道府県・政令指定都市。nilなら候補の先頭(制覇率が最も高いもの)を使う。
    @State private var prefectureCode: String?
    @State private var cityCode: String?

    // MARK: この街のカード

    @State private var townKind: MunicipalityShareKind
    /// この街でできることで載せるスポットの位置(`subject.spots`の添字)。
    @State private var spotIndex = 0
    @State private var isTownMapLoaded = false

    // MARK: 地図のカード

    @State private var fill: ShareCardFill = .municipalities
    /// 地図の読み込みを終えた範囲。読み込みに失敗した都道府県・政令指定都市も含む(地図なしのカードで描く)。
    @State private var loadedScopes: Set<ShareScope> = []

    // MARK: どのカードにも共通

    @State private var layout: ShareCardLayout = .story
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    /// 写真を読み込めなかったときの案内。
    @State private var photoErrorMessage: String?
    @State private var boxPosition: ShareCardBoxPosition = .bottom
    @AppStorage(ShareCardBoxStyle.storageKey) private var boxStyle: ShareCardBoxStyle = ShareCardBoxStyle.defaultStyle
    @State private var rendered: RenderedShareCard?

    private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "ShareCardSheet")

    init(entry: ShareCardSheetEntry, silhouetteStore: SilhouetteMapStore? = nil) {
        self.entry = entry
        self.silhouetteStore = silhouetteStore
        switch entry {
        case .region(let scope):
            _isTownSelected = State(initialValue: false)
            _regionKind = State(initialValue: scope.kind)
            if case .prefecture(let code) = scope { _prefectureCode = State(initialValue: code) }
            if case .designatedCity(let code) = scope { _cityCode = State(initialValue: code) }
            _townKind = State(initialValue: .highlights)
        case .town(let subject, let initialKind):
            _isTownSelected = State(initialValue: true)
            _regionKind = State(initialValue: .japan)
            // 入口は`canShare`のときだけ出すので、出せる種類が無いことは無い。万一のときは何も描かない(`renderTown`)。
            _townKind = State(initialValue: subject.initialKind(preferred: initialKind) ?? .highlights)
        }
    }

    private var store: SilhouetteMapStore { silhouetteStore ?? environmentStore ?? fallbackStore }

    private var townSubject: MunicipalityShareSubject? {
        if case .town(let subject, _) = entry { return subject }
        return nil
    }

    var body: some View {
        let summary = summaryStore.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        let candidates = ShareScopeCandidates(summary: summary, including: includedScope)
        let target = selectedTarget(in: candidates)
        let firstVisitContent = target == .town && townKind == .firstVisit ? makeFirstVisitContent(summary: summary) : nil
        let backdropKey = backdropKey(for: target)
        ShareCardSheetScaffold(
            navigationTitle: navigationTitle,
            footnote: footnote(for: target),
            rendered: rendered,
            layout: $layout,
            // 箱を動かせるのは写真を敷いたときだけ。写真が無いカードは地図と箱の並びが決まっている。
            onTapPreview: photo == nil ? nil : { boxPosition = boxPosition.next }
        ) {
            scopeControls(candidates: candidates, summary: summary, target: target)
            if target == .town {
                townKindControls
            }
            // 塗りの単位を選べるのは全国だけ。都道府県・政令指定都市は区画がそのまま市区町村・区になる。
            if target == .region(.japan) {
                ShareCardLabeledControl("塗り") {
                    Picker("塗り", selection: $fill) {
                        ForEach(ShareCardFill.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            photoControls
            boxStyleControls
        }
        .task(id: townSubject?.target) {
            guard let townTarget = townSubject?.target else { return }
            await townTarget.loadMap(in: store)
            isTownMapLoaded = true
        }
        .task(id: regionScope(of: target)) {
            guard let scope = regionScope(of: target) else { return }
            await loadMap(for: scope, summary: summary)
        }
        // 写真を敷いている間は地図が見えないので撮らない。写真を外したら、その時の範囲・種類・形で撮る。
        .task(id: BackdropRequest(key: backdropKey, isMapReady: isMapReady(for: target), needsMap: photo == nil)) {
            guard photo == nil, let backdropKey, let map = silhouetteMap(for: target) else { return }
            await snapshotStore.loadBackdropIfNeeded(for: backdropKey, map: map)
        }
        .task(id: photoItem) { await loadPhoto() }
        // 地図の読み込みが終わったとき・本物の地図が届いたとき・選択肢を変えたときに描き直す。
        .task(id: RenderKey(
            target: target, townKind: townKind, spotIndex: spotIndex, layout: layout, fill: fill,
            firstVisit: firstVisitContent, isMapReady: isMapReady(for: target),
            hasBackdrop: backdropKey.flatMap(snapshotStore.backdrop(for:)) != nil,
            photoID: photo.map(ObjectIdentifier.init), boxStyle: boxStyle, boxPosition: boxPosition
        )) {
            rendered = render(target: target, summary: summary, firstVisit: firstVisitContent)
        }
    }

    private var navigationTitle: String {
        if let townSubject { return "\(townSubject.target.name)をシェア" }
        return "地図をシェア"
    }

    private func footnote(for target: ShareCardTarget) -> String {
        switch target {
        case .region:
            return "画像には塗った地図と件数だけが入ります。ピン・住所・訪れた日時、写真の位置情報は入りません。"
        case .town where townKind == .firstVisit:
            return "画像には街の名前と、訪れた市区町村の数だけが入ります。訪れた日時や場所、写真の位置情報は入りません。"
        case .town:
            return "画像には街の名前と形、選んだ話題だけが入ります。訪れた日時や場所、写真の位置情報は入りません。"
        }
    }

    // MARK: - 範囲

    /// 候補の一覧に必ず入れる範囲。開いた画面の範囲(市区町村から開いたらその県)が候補とずれないようにする。
    private var includedScope: ShareScope? {
        switch entry {
        case .region(let scope): scope
        case .town(let subject, _): .prefecture(code: String(subject.target.code.prefix(2)))
        }
    }

    private func selectedTarget(in candidates: ShareScopeCandidates) -> ShareCardTarget {
        if townSubject != nil, isTownSelected { return .town }
        return .region(selectedScope(in: candidates))
    }

    private func selectedScope(in candidates: ShareScopeCandidates) -> ShareScope {
        switch regionKind {
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

    private func regionScope(of target: ShareCardTarget) -> ShareScope? {
        if case .region(let scope) = target { return scope }
        return nil
    }

    @ViewBuilder
    private func scopeControls(candidates: ShareScopeCandidates, summary: ExplorationSummary, target: ShareCardTarget) -> some View {
        if let townSubject {
            townScopePicker(options: TownShareScopeOption.options(townCode: townSubject.target.code, prefectures: summary.prefectures), target: target)
        } else {
            regionScopePickers(candidates)
        }
    }

    /// 「この街 / 愛知県 / 全国」。1段だけ上と全国に切り替える(政令指定都市は政令指定都市の画面のメニューから)。
    private func townScopePicker(options: [TownShareScopeOption], target: ShareCardTarget) -> some View {
        let selection = Binding<ShareCardTarget>(
            get: { target },
            set: { newValue in
                switch newValue {
                case .town:
                    isTownSelected = true
                case .region(let scope):
                    isTownSelected = false
                    regionKind = scope.kind
                    if case .prefecture(let code) = scope { prefectureCode = code }
                }
            }
        )
        return ShareCardLabeledControl("範囲") {
            Picker("範囲", selection: selection) {
                ForEach(options) { Text($0.title).tag($0.target) }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private func regionScopePickers(_ candidates: ShareScopeCandidates) -> some View {
        let kinds = candidates.availableKinds
        // まだどこも訪れていないときは全国しか無いので、範囲の選択は出さない。
        if kinds.count > 1 {
            ShareCardLabeledControl("範囲") {
                Picker("範囲", selection: $regionKind) {
                    ForEach(kinds) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        switch regionKind {
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

    // MARK: - 選択肢

    @ViewBuilder
    private var townKindControls: some View {
        if let townSubject {
            let kinds = townSubject.availableKinds
            if kinds.count > 1 {
                ShareCardLabeledControl("カード") {
                    Picker("カード", selection: $townKind) {
                        ForEach(kinds) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            if townKind == .spots, townSubject.spots.count > 1 {
                ShareCardLabeledControl("載せるスポット") {
                    Picker("載せるスポット", selection: $spotIndex) {
                        ForEach(Array(townSubject.spots.enumerated()), id: \.offset) { index, spot in
                            Text(spot.name).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Pop.theme)
                }
            }
        }
    }

    private var photoControls: some View {
        ShareCardLabeledControl("背景") {
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photo == nil ? "写真を選ぶ" : "写真を変える", systemImage: "photo")
                }
                .buttonStyle(.bordered)
                .tint(Pop.theme)
                if photo != nil {
                    Button("写真を外す", systemImage: "xmark.circle") {
                        photoItem = nil
                        photo = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(Pop.muted)
                }
            }
            if let photoErrorMessage {
                Text(photoErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var boxStyleControls: some View {
        ShareCardLabeledControl("箱の見た目") {
            Picker("箱の見た目", selection: $boxStyle) {
                ForEach(ShareCardBoxStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 地図

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
    private func isMapReady(for target: ShareCardTarget) -> Bool {
        switch target {
        case .town:
            return isTownMapLoaded || townSubject.flatMap { $0.target.map(in: store) } != nil
        case .region(let scope):
            if loadedScopes.contains(scope) { return true }
            switch scope {
            case .japan: return store.shareCardMaps != nil
            case .prefecture(let code): return store.sharePrefectureMaps[code] != nil
            case .designatedCity(let code): return store.shareDesignatedCityMaps[code] != nil
            }
        }
    }

    /// 本物の地図を重ねるシルエット。全国は2種類の地図が同じ枠なので、市区町村の地図で範囲を決める。
    private func silhouetteMap(for target: ShareCardTarget) -> SilhouetteMap? {
        switch target {
        case .town: townSubject?.target.map(in: store)
        case .region(.japan): store.shareCardMaps?.municipalityMap
        case .region(.prefecture(let code)): store.sharePrefectureMaps[code]
        case .region(.designatedCity(let code)): store.shareDesignatedCityMaps[code]
        }
    }

    /// 本物の地図は範囲とカードの地図の枠(形・種類で変わる)ごとに撮る。豆知識は見出しの下の枠、初訪問はカード全体に敷く。
    private func backdropKey(for target: ShareCardTarget) -> ShareMapSnapshotStore.Key? {
        let isStory = layout == .story
        switch target {
        case .town:
            guard let townSubject else { return nil }
            let box: ShareCardMapBox = switch townKind {
            case .firstVisit: isStory ? .firstVisitStory : .firstVisitSquare
            case .highlights, .legend, .spots: isStory ? .triviaStory : .triviaSquare
            }
            return ShareMapSnapshotStore.Key(id: townSubject.target.snapshotID, box: box)
        case .region(.japan):
            return ShareMapSnapshotStore.Key(id: "japan", box: isStory ? .japanStory : .japanSquare)
        case .region(.prefecture(let code)):
            return ShareMapSnapshotStore.Key(id: "prefecture-\(code)", box: isStory ? .regionStory : .regionSquare)
        case .region(.designatedCity(let code)):
            return ShareMapSnapshotStore.Key(id: "city-\(code)", box: isStory ? .regionStory : .regionSquare)
        }
    }

    // MARK: - 描画

    private struct BackdropRequest: Hashable {
        let key: ShareMapSnapshotStore.Key?
        let isMapReady: Bool
        let needsMap: Bool
    }

    private struct RenderKey: Hashable {
        let target: ShareCardTarget
        let townKind: MunicipalityShareKind
        let spotIndex: Int
        let layout: ShareCardLayout
        let fill: ShareCardFill
        let firstVisit: FirstVisitShareCardContent?
        let isMapReady: Bool
        let hasBackdrop: Bool
        let photoID: ObjectIdentifier?
        let boxStyle: ShareCardBoxStyle
        let boxPosition: ShareCardBoxPosition
    }

    private func makeFirstVisitContent(summary: ExplorationSummary) -> FirstVisitShareCardContent? {
        guard let townSubject else { return nil }
        return FirstVisitShareCardContent(
            municipalityName: townSubject.target.name, prefectureName: townSubject.target.prefectureName, progress: summary.progress
        )
    }

    private func render(target: ShareCardTarget, summary: ExplorationSummary, firstVisit: FirstVisitShareCardContent?) -> RenderedShareCard? {
        // 写真があるときは本物の地図を使わない(写真の上に塗りだけを描く)。
        let backdrop = photo == nil ? backdropKey(for: target).flatMap(snapshotStore.backdrop(for:)) : nil
        switch target {
        case .town:
            return renderTown(firstVisit: firstVisit, backdrop: backdrop)
        case .region(let scope):
            return renderRegion(scope: scope, summary: summary, backdrop: backdrop)
        }
    }

    /// 写真があれば地図を待たずに描く。写真が無いときは形を読み込み終えてから描く(読み込めなければアイコンだけのカード)。
    private func renderTown(firstVisit: FirstVisitShareCardContent?, backdrop: ShareMapBackdrop?) -> RenderedShareCard? {
        guard let townSubject, photo != nil || isMapReady(for: .town), townSubject.availableKinds.contains(townKind) else { return nil }
        let townTarget = townSubject.target
        let map = photo == nil ? townTarget.map(in: store) : nil
        let highlightedCodes = map.map(townTarget.highlightedCodes(in:)) ?? []

        if townKind == .firstVisit {
            guard let firstVisit else { return nil }
            let view = FirstVisitShareCardView(
                content: firstVisit, layout: layout, photo: photo, map: map, highlightedCodes: highlightedCodes, backdrop: backdrop,
                boxStyle: boxStyle, boxPosition: boxPosition
            )
            return ShareCardRenderer.render(view, layout: layout)
                .map { RenderedShareCard(image: $0, message: firstVisit.shareText, title: "\(townTarget.name) 初訪問") }
        }

        guard let topic = townSubject.topic(for: townKind, spotIndex: spotIndex) else { return nil }
        let content = TriviaShareCardContent(
            municipalityName: townTarget.name, prefectureName: townTarget.prefectureName, isVisited: townSubject.isVisited, topic: topic
        )
        let view = TriviaShareCardView(
            content: content, layout: layout, map: map, highlightedCodes: highlightedCodes, backdrop: backdrop, photo: photo,
            boxStyle: boxStyle, boxPosition: boxPosition
        )
        return ShareCardRenderer.render(view, layout: layout)
            .map { RenderedShareCard(image: $0, message: content.shareText, title: "\(townTarget.name)の\(content.title)") }
    }

    /// カードの日付は描いた時点の日にする(訪問日ではない)。
    private func renderRegion(scope: ShareScope, summary: ExplorationSummary, backdrop: ShareMapBackdrop?) -> RenderedShareCard? {
        guard isMapReady(for: .region(scope)) else { return nil }
        switch scope {
        case .japan:
            // 全国の地図は読み込めないとカードの主役が無くなるので、地図ができるまでは描かない(1.8.0 (1)と同じ)。
            guard let maps = store.shareCardMaps else { return nil }
            let content = ShareCardContent(summary: summary, date: .now)
            let view = ShareCardView(
                content: content, layout: layout, fill: fill, maps: maps, backdrop: backdrop,
                photo: photo, boxStyle: boxStyle, boxPosition: boxPosition
            )
            return ShareCardRenderer.render(view, layout: layout)
                .map { RenderedShareCard(image: $0, message: content.shareText, title: "わたしの日本地図") }
        case .prefecture(let code):
            guard let prefecture = summary.prefectures.first(where: { $0.code == code }) else { return nil }
            return renderRegionCard(RegionShareCardContent(prefecture: prefecture, date: .now), map: store.sharePrefectureMaps[code], backdrop: backdrop)
        case .designatedCity(let code):
            guard let city = summary.designatedCities.first(where: { $0.code == code }) else { return nil }
            return renderRegionCard(RegionShareCardContent(city: city, date: .now), map: store.shareDesignatedCityMaps[code], backdrop: backdrop)
        }
    }

    private func renderRegionCard(_ content: RegionShareCardContent, map: SilhouetteMap?, backdrop: ShareMapBackdrop?) -> RenderedShareCard? {
        let view = RegionShareCardView(
            content: content, layout: layout, map: map, backdrop: backdrop, photo: photo, boxStyle: boxStyle, boxPosition: boxPosition
        )
        return ShareCardRenderer.render(view, layout: layout)
            .map { RenderedShareCard(image: $0, message: content.shareText, title: content.headline) }
    }

    /// 選んだ写真を読み込む。カードの大きさ(最大1080×1920px)を覆う大きさまで縮めて、メモリを抑える。
    /// 写真の位置情報(Exif)は、カードを描き直した画像には入らない。
    private func loadPhoto() async {
        guard let photoItem else { return }
        photoErrorMessage = nil
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                photoErrorMessage = "写真を読み込めませんでした"
                return
            }
            let pixelSize = ShareCardLayout.story.pixelSize
            let scale = min(1, max(pixelSize.width / image.size.width, pixelSize.height / image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let resized = await image.byPreparingThumbnail(ofSize: size) ?? image
            guard !Task.isCancelled else { return }
            photo = resized
        } catch {
            logger.error("写真を読み込めませんでした: \(String(describing: error), privacy: .public)")
            photoErrorMessage = "写真を読み込めませんでした"
        }
    }
}
