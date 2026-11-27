import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import os

/// 市区町村のシェア画面で切り替えるカードの種類。並び順は画面の切り替えの並び。
enum MunicipalityShareKind: String, CaseIterable, Identifiable, Hashable {
    case firstVisit
    case highlights
    case legend
    case spots

    var id: Self { self }

    /// 切り替えの見出し。4つを横に並べても切れないよう短くする(「この街でできること」は「できること」)。
    var title: String {
        switch self {
        case .firstVisit: "初訪問"
        case .highlights: "みどころ"
        case .legend: "都市伝説"
        case .spots: "できること"
        }
    }
}

/// 市区町村のシェア画面に渡す、その街のカードの材料。
///
/// 図鑑・初訪問のお祝いのどこから開いても同じ形で渡し、同じ画面(`MunicipalityShareSheet`)を開く。
/// SwiftDataのモデル(`Municipality`)をそのまま持たず値で持つのは、出せるカードの判定をテストしやすくするため。
struct MunicipalityShareSubject: Hashable {
    let target: ShareMunicipalityTarget
    let isVisited: Bool
    /// みどころ(マスタの「豆知識(有名なもの)」)。
    let highlightsText: String
    /// 怪奇・都市伝説(マスタの「豆知識(歴史)」)。
    let legendText: String
    /// この街でできること(みどころのマスタの順)。
    let spots: [YorimichiSpot]

    init(target: ShareMunicipalityTarget, isVisited: Bool, highlightsText: String, legendText: String, spots: [YorimichiSpot]) {
        self.target = target
        self.isVisited = isVisited
        self.highlightsText = highlightsText
        self.legendText = legendText
        self.spots = spots
    }

    /// マスタの市区町村から作る。スポットは図鑑と同じく、マスタのJSONから読む。
    init(target: ShareMunicipalityTarget, isVisited: Bool, municipality: Municipality) {
        self.init(
            target: target,
            isVisited: isVisited,
            highlightsText: municipality.famousThingsTrivia,
            legendText: municipality.historyTrivia,
            spots: YorimichiSpot.spots(fromJSON: municipality.spotsJSON)
        )
    }

    /// この街で出せるカードの種類。
    var availableKinds: [MunicipalityShareKind] {
        Self.availableKinds(isVisited: isVisited, highlightsText: highlightsText, legendText: legendText, hasSpots: !spots.isEmpty)
    }

    /// 出せるカードが1つでもあるか。無ければ入口のボタンを出さない。
    var canShare: Bool { !availableKinds.isEmpty }

    /// 出せるカードの種類。
    /// - 初訪問: 訪れた街だけ(まだ行っていない街の「初訪問」は事実と違うため)
    /// - みどころ: 空欄でなければ
    /// - 都市伝説: 空欄と「特に有名な怪談・都市伝説はありません」の決まり文句でなければ
    /// - この街でできること: スポットが1件以上あれば
    static func availableKinds(isVisited: Bool, highlightsText: String, legendText: String, hasSpots: Bool) -> [MunicipalityShareKind] {
        var kinds: [MunicipalityShareKind] = []
        if isVisited { kinds.append(.firstVisit) }
        if TriviaShareCardContent.isShareableHighlights(highlightsText) { kinds.append(.highlights) }
        if TriviaShareCardContent.isShareableLegend(legendText) { kinds.append(.legend) }
        if hasSpots { kinds.append(.spots) }
        return kinds
    }

    /// 開いたときに選んでおく種類。押した入口の種類が出せなければ、出せる最初の種類にする。
    func initialKind(preferred: MunicipalityShareKind?) -> MunicipalityShareKind? {
        let kinds = availableKinds
        if let preferred, kinds.contains(preferred) { return preferred }
        return kinds.first
    }

    /// 豆知識のカードの話題。初訪問は豆知識のカードではないのでnil。
    func topic(for kind: MunicipalityShareKind, spotIndex: Int) -> TriviaShareCardContent.Topic? {
        switch kind {
        case .firstVisit:
            return nil
        case .highlights:
            return .highlights(highlightsText)
        case .legend:
            return .legend(legendText)
        case .spots:
            guard spots.indices.contains(spotIndex) else { return nil }
            return TriviaShareCardContent.spotTopic(spots[spotIndex])
        }
    }
}

/// 市区町村をシェアする画面。初訪問・みどころ・都市伝説・この街でできることを1つの画面で切り替える。
///
/// 図鑑の各見出しの共有ボタン・図鑑のツールバー・初訪問のお祝い・政令指定都市のメニューのどこから開いても
/// この画面にし、押した入口の種類を選んだ状態で開く。
/// 選んだ写真は種類を切り替えても外さない(同じ写真で種類を見比べられるように)。写真が無ければ本物の地図を薄く敷く。
struct MunicipalityShareSheet: View {
    let subject: MunicipalityShareSubject

    @Environment(SilhouetteMapStore.self) private var environmentStore: SilhouetteMapStore?
    @Query(sort: \Municipality.code) private var municipalities: [Municipality]
    @Query private var savedPlaces: [SavedPlace]
    @Query private var visitedPrefectures: [VisitedPrefecture]
    @State private var summaryStore = SavedPlacesStore()
    @State private var fallbackStore = SilhouetteMapStore()
    @State private var snapshotStore = ShareMapSnapshotStore()
    @State private var kind: MunicipalityShareKind
    /// この街でできることで載せるスポットの位置(`subject.spots`の添字)。
    @State private var spotIndex = 0
    @State private var layout: ShareCardLayout = .story
    @State private var isMapLoaded = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    /// 写真を読み込めなかったときの案内。
    @State private var photoErrorMessage: String?
    @State private var rendered: RenderedShareCard?

    private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "MunicipalityShare")

    /// - Parameter initialKind: 押した入口の種類。出せない種類なら、出せる最初の種類で開く。
    init(subject: MunicipalityShareSubject, initialKind: MunicipalityShareKind? = nil) {
        self.subject = subject
        // 入口は`canShare`のときだけ出すので、出せる種類が無いことは無い。万一のときは何も描かない(`render`)。
        _kind = State(initialValue: subject.initialKind(preferred: initialKind) ?? .highlights)
    }

    private var store: SilhouetteMapStore { environmentStore ?? fallbackStore }
    private var target: ShareMunicipalityTarget { subject.target }

    /// 本物の地図を撮る範囲。豆知識は見出しの下の枠、初訪問はカード全体に敷く。
    private var snapshotKey: ShareMapSnapshotStore.Key {
        let box: ShareCardMapBox = switch (kind, layout) {
        case (.firstVisit, .story): .firstVisitStory
        case (.firstVisit, .square): .firstVisitSquare
        case (_, .story): .triviaStory
        case (_, .square): .triviaSquare
        }
        return ShareMapSnapshotStore.Key(id: target.snapshotID, box: box)
    }

    private var footnote: String {
        switch kind {
        case .firstVisit:
            "画像には街の名前と、訪れた市区町村の数だけが入ります。訪れた日時や場所、写真の位置情報は入りません。"
        case .highlights, .legend, .spots:
            "画像には街の名前と形、選んだ話題だけが入ります。訪れた日時や場所、写真の位置情報は入りません。"
        }
    }

    var body: some View {
        // 全国の訪問数は初訪問のカードにだけ要る。市区町村の全件を数えるので、ほかの種類では数えない。
        let firstVisitContent = kind == .firstVisit ? makeFirstVisitContent() : nil
        ShareCardSheetScaffold(
            navigationTitle: "\(target.name)をシェア",
            footnote: footnote,
            rendered: rendered,
            layout: $layout
        ) {
            kindControls
            photoControls
        }
        .task(id: target) {
            await target.loadMap(in: store)
            isMapLoaded = true
        }
        // 写真を敷いている間は地図が見えないので撮らない。写真を外したら、その時の種類と形で撮る。
        .task(id: BackdropRequest(key: snapshotKey, isMapLoaded: isMapLoaded, needsMap: photo == nil)) {
            guard photo == nil, let map = target.map(in: store) else { return }
            await snapshotStore.loadBackdropIfNeeded(for: snapshotKey, map: map)
        }
        .task(id: photoItem) { await loadPhoto() }
        .task(id: RenderKey(
            kind: kind, spotIndex: spotIndex, layout: layout, firstVisit: firstVisitContent, isMapLoaded: isMapLoaded,
            hasBackdrop: snapshotStore.backdrop(for: snapshotKey) != nil, photoID: photo.map(ObjectIdentifier.init)
        )) {
            rendered = render(firstVisit: firstVisitContent)
        }
    }

    // MARK: - 選択肢

    @ViewBuilder
    private var kindControls: some View {
        let kinds = subject.availableKinds
        if kinds.count > 1 {
            ShareCardLabeledControl("カード") {
                Picker("カード", selection: $kind) {
                    ForEach(kinds) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        if kind == .spots, subject.spots.count > 1 {
            ShareCardLabeledControl("載せるスポット") {
                Picker("載せるスポット", selection: $spotIndex) {
                    ForEach(Array(subject.spots.enumerated()), id: \.offset) { index, spot in
                        Text(spot.name).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .tint(Pop.theme)
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

    // MARK: - 描画

    private struct BackdropRequest: Hashable {
        let key: ShareMapSnapshotStore.Key
        let isMapLoaded: Bool
        let needsMap: Bool
    }

    private struct RenderKey: Hashable {
        let kind: MunicipalityShareKind
        let spotIndex: Int
        let layout: ShareCardLayout
        let firstVisit: FirstVisitShareCardContent?
        let isMapLoaded: Bool
        let hasBackdrop: Bool
        let photoID: ObjectIdentifier?
    }

    private func makeFirstVisitContent() -> FirstVisitShareCardContent {
        let summary = summaryStore.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        return FirstVisitShareCardContent(municipalityName: target.name, prefectureName: target.prefectureName, progress: summary.progress)
    }

    /// 写真があれば地図を待たずに描く。写真が無いときは形を読み込み終えてから描く(読み込めなければアイコンだけのカード)。
    private func render(firstVisit: FirstVisitShareCardContent?) -> RenderedShareCard? {
        guard photo != nil || isMapLoaded, subject.availableKinds.contains(kind) else { return nil }
        let map = photo == nil ? target.map(in: store) : nil
        let highlightedCodes = map.map(target.highlightedCodes(in:)) ?? []
        let backdrop = photo == nil ? snapshotStore.backdrop(for: snapshotKey) : nil

        if kind == .firstVisit {
            guard let firstVisit else { return nil }
            let view = FirstVisitShareCardView(
                content: firstVisit, layout: layout, photo: photo, map: map, highlightedCodes: highlightedCodes, backdrop: backdrop
            )
            return ShareCardRenderer.render(view, layout: layout)
                .map { RenderedShareCard(image: $0, message: firstVisit.shareText, title: "\(target.name) 初訪問") }
        }

        guard let topic = subject.topic(for: kind, spotIndex: spotIndex) else { return nil }
        let content = TriviaShareCardContent(
            municipalityName: target.name, prefectureName: target.prefectureName, isVisited: subject.isVisited, topic: topic
        )
        let view = TriviaShareCardView(
            content: content, layout: layout, map: map, highlightedCodes: highlightedCodes, backdrop: backdrop, photo: photo
        )
        return ShareCardRenderer.render(view, layout: layout)
            .map { RenderedShareCard(image: $0, message: content.shareText, title: "\(target.name)の\(content.title)") }
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
