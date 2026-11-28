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
/// - 都道府県: 「県内の市区町村 / 全国の都道府県」を切り替える(1.8.0 (7))。全国の都道府県は日本地図でその県を強く示す。
/// - レイアウト: 中身の種類ごとに選べるもの(`ShareCardSubjectKind.availableLayouts`)が2つ以上あるときだけ選ばせ、
///   最後に選んだものを地図のカード・街のカードで別々に覚える(`ShareCardLayoutFamily`)。
///
/// 何を描くか(範囲・種類・塗り)は`ShareCardSelection`、その中身の作り方は`ShareCardSubjectFactory`、
/// 見た目は`ShareCardModel`にまとめ、この画面は選択肢の並びと読み込みのきっかけだけを持つ。
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
    @State private var prefectureFocus: PrefectureShareFocus = .municipalities

    // MARK: この街のカード

    @State private var townKind: MunicipalityShareKind
    @State private var spotIndex = 0
    @State private var isTownMapLoaded = false

    // MARK: 地図のカード

    @State private var fill: ShareCardFill = .municipalities
    /// 地図の読み込みを終えた範囲。読み込みに失敗した都道府県・政令指定都市も含む(地図なしのカードで描く)。
    @State private var loadedScopes: Set<ShareScope> = []

    // MARK: どのカードにも共通

    @State private var size: ShareCardSize = .story
    /// 最後に選んだレイアウト。地図のカードと街のカードで別々に覚える。
    @AppStorage(ShareCardLayoutFamily.map.storageKey) private var mapLayout: ShareCardLayout = .standard
    @AppStorage(ShareCardLayoutFamily.town.storageKey) private var townLayout: ShareCardLayout = .standard
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
            // 入口は`canShare`のときだけ出すので、出せる種類が無いことは無い。万一のときは何も描かない。
            _townKind = State(initialValue: subject.initialKind(preferred: initialKind) ?? .highlights)
        }
    }

    private var store: SilhouetteMapStore { silhouetteStore ?? environmentStore ?? fallbackStore }

    private var townSubject: MunicipalityShareSubject? {
        if case .town(let subject, _) = entry { return subject }
        return nil
    }

    private var factory: ShareCardSubjectFactory {
        ShareCardSubjectFactory(store: store, townSubject: townSubject, loadedScopes: loadedScopes, isTownMapLoaded: isTownMapLoaded)
    }

    var body: some View {
        let summary = summaryStore.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        let candidates = ShareScopeCandidates(summary: summary, including: includedScope)
        let selection = makeSelection(candidates: candidates)
        let layout = selection.subjectKind.resolvedLayout(storedLayout(for: selection.subjectKind))
        let factory = factory
        let backdropKey = factory.backdropKey(for: selection, size: size)
        let isMapReady = factory.isMapReady(for: selection)
        ShareCardSheetScaffold(
            navigationTitle: navigationTitle,
            footnote: footnote(for: selection),
            rendered: rendered,
            size: $size,
            onTapPreview: layout.canMoveBox(hasPhoto: photo != nil) ? { boxPosition = boxPosition.next } : nil
        ) {
            scopeControls(candidates: candidates, summary: summary, target: selection.target)
            if selection.target == .town {
                townKindControls
            }
            // 塗りの単位を選べるのは全国と都道府県だけ。政令指定都市は区画がそのまま区になる。
            if selection.target == .region(.japan) {
                ShareCardSegmentedControl(title: "塗り", selection: $fill, options: ShareCardFill.allCases, label: \.title)
            }
            if case .region(.prefecture) = selection.target {
                ShareCardSegmentedControl(
                    title: "塗り", selection: $prefectureFocus, options: PrefectureShareFocus.allCases, label: \.title
                )
            }
            layoutControls(for: selection.subjectKind)
            ShareCardPhotoControls(photoItem: $photoItem, photo: $photo, errorMessage: photoErrorMessage)
            ShareCardSegmentedControl(title: "箱の見た目", selection: $boxStyle, options: ShareCardBoxStyle.allCases, label: \.title)
        }
        .task(id: townSubject?.target) {
            guard let townTarget = townSubject?.target else { return }
            await townTarget.loadMap(in: store)
            isTownMapLoaded = true
        }
        .task(id: selection.mapScope) {
            guard let scope = selection.mapScope else { return }
            await loadMap(for: scope, summary: summary)
        }
        // 写真を敷いている間は地図が見えないので撮らない。写真を外したら、その時の範囲・種類・形で撮る。
        .task(id: BackdropRequest(key: backdropKey, isMapReady: isMapReady, needsMap: photo == nil)) {
            guard photo == nil, let backdropKey, let map = factory.silhouetteMap(for: selection) else { return }
            await snapshotStore.loadBackdropIfNeeded(for: backdropKey, map: map)
        }
        .task(id: photoItem) { await loadPhoto() }
        // 地図の読み込みが終わったとき・本物の地図が届いたとき・選択肢や数を変えたときに描き直す。
        .task(id: RenderKey(
            selection: selection, size: size, layout: layout, isMapReady: isMapReady,
            hasBackdrop: backdropKey.flatMap(snapshotStore.backdrop(for:)) != nil,
            photoID: photo.map(ObjectIdentifier.init), boxStyle: boxStyle, boxPosition: boxPosition,
            visitedCount: summary.progress.visited, visitedPrefectureCount: summary.visitedPrefectureCount
        )) {
            guard let subject = factory.subject(for: selection, summary: summary, hasPhoto: photo != nil) else {
                rendered = nil
                return
            }
            let model = ShareCardModel(
                subject: subject, layout: layout, size: size, photo: photo,
                // 写真があるときは本物の地図を使わない(写真の上に塗りだけを描く)。
                backdrop: photo == nil ? backdropKey.flatMap(snapshotStore.backdrop(for:)) : nil,
                boxStyle: boxStyle, boxPosition: boxPosition
            )
            rendered = ShareCardRenderer.render(model)
        }
    }

    private var navigationTitle: String {
        if let townSubject { return "\(townSubject.target.name)をシェア" }
        return "地図をシェア"
    }

    private func footnote(for selection: ShareCardSelection) -> String {
        switch selection.target {
        case .region:
            return "画像には塗った地図と件数だけが入ります。ピン・住所・訪れた日時、写真の位置情報は入りません。"
        case .town where selection.townKind == .firstVisit:
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

    private func makeSelection(candidates: ShareScopeCandidates) -> ShareCardSelection {
        let target: ShareCardTarget = townSubject != nil && isTownSelected ? .town : .region(selectedScope(in: candidates))
        return ShareCardSelection(target: target, townKind: townKind, spotIndex: spotIndex, fill: fill, prefectureFocus: prefectureFocus)
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

    @ViewBuilder
    private func scopeControls(candidates: ShareScopeCandidates, summary: ExplorationSummary, target: ShareCardTarget) -> some View {
        if let townSubject {
            townScopePicker(options: TownShareScopeOption.options(townCode: townSubject.target.code, prefectures: summary.prefectures), target: target)
        } else {
            ShareCardRegionScopeControls(candidates: candidates, kind: $regionKind, prefectureCode: $prefectureCode, cityCode: $cityCode)
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

    // MARK: - 選択肢

    @ViewBuilder
    private var townKindControls: some View {
        if let townSubject {
            let kinds = townSubject.availableKinds
            if kinds.count > 1 {
                ShareCardSegmentedControl(title: "カード", selection: $townKind, options: kinds, label: \.title)
            }
            if townKind == .spots, townSubject.spots.count > 1 {
                ShareCardMenuPicker(
                    title: "載せるスポット", selection: $spotIndex,
                    options: townSubject.spots.enumerated().map { ($0.offset, $0.element.name) }
                )
            }
        }
    }

    /// 選べるレイアウトが2つ以上あるときだけ出す。選んだものは、その種類の仲間(地図・街)の分として覚える。
    @ViewBuilder
    private func layoutControls(for kind: ShareCardSubjectKind) -> some View {
        let layouts = kind.availableLayouts
        if layouts.count > 1 {
            let selection = Binding<ShareCardLayout>(
                get: { kind.resolvedLayout(storedLayout(for: kind)) },
                set: { newValue in
                    switch kind.family {
                    case .map: mapLayout = newValue
                    case .town: townLayout = newValue
                    }
                }
            )
            ShareCardSegmentedControl(title: "レイアウト", selection: selection, options: layouts, label: \.title)
        }
    }

    private func storedLayout(for kind: ShareCardSubjectKind) -> ShareCardLayout {
        switch kind.family {
        case .map: mapLayout
        case .town: townLayout
        }
    }

    // MARK: - 読み込み

    private struct BackdropRequest: Hashable {
        let key: ShareMapSnapshotStore.Key?
        let isMapReady: Bool
        let needsMap: Bool
    }

    private struct RenderKey: Hashable {
        let selection: ShareCardSelection
        let size: ShareCardSize
        let layout: ShareCardLayout
        let isMapReady: Bool
        let hasBackdrop: Bool
        let photoID: ObjectIdentifier?
        let boxStyle: ShareCardBoxStyle
        let boxPosition: ShareCardBoxPosition
        /// 初訪問・全国の都道府県のカードに載せる数。記録が増えたら描き直す。
        let visitedCount: Int
        let visitedPrefectureCount: Int
    }

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
            let pixelSize = ShareCardSize.story.pixelSize
            let scale = min(1, max(pixelSize.width / image.size.width, pixelSize.height / image.size.height))
            let resizedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let resized = await image.byPreparingThumbnail(ofSize: resizedSize) ?? image
            guard !Task.isCancelled else { return }
            photo = resized
        } catch {
            logger.error("写真を読み込めませんでした: \(String(describing: error), privacy: .public)")
            photoErrorMessage = "写真を読み込めませんでした"
        }
    }
}
