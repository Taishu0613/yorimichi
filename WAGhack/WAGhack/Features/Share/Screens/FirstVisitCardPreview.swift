import SwiftData
import SwiftUI

/// 初訪問のお祝いのシートに置く、その街の初訪問のカードのプレビューと「シェアする」(1.8.0 (6))。
///
/// 記録した直後がいちばんシェアしたい時なので、シェア画面を開かなくても、できあがるカードを見てそのまま共有できるようにする。
/// 「シェアする」で共有するのはプレビューと同じ画像。シートの高さを抑えるため正方形のカードにする。
/// プレビューを押すと、写真や種類・形を変えられるシェア画面(`ShareCardSheet`)を開く。
struct FirstVisitCardPreview: View {
    let subject: MunicipalityShareSubject
    /// プレビューを押したとき。シェア画面を開く。
    let openEditor: () -> Void

    @Environment(SilhouetteMapStore.self) private var environmentStore: SilhouetteMapStore?
    @Query(sort: \Municipality.code) private var municipalities: [Municipality]
    @Query private var savedPlaces: [SavedPlace]
    @Query private var visitedPrefectures: [VisitedPrefecture]
    @State private var summaryStore = SavedPlacesStore()
    @State private var fallbackStore = SilhouetteMapStore()
    @State private var snapshotStore = ShareMapSnapshotStore()
    @State private var isMapLoaded = false
    @State private var isLocationMapLoaded = false
    @State private var rendered: RenderedShareCard?
    /// シェア画面で最後に選んだ箱の見た目・形の見せ方に合わせる(シェア画面を開いたときと同じカードにするため)。
    @AppStorage(ShareCardBoxStyle.storageKey) private var boxStyle: ShareCardBoxStyle = .defaultStyle
    @AppStorage(ShareCardShapeMode.storageKey) private var shapeMode: ShareCardShapeMode = .defaultMode

    /// 写真はまだ無いので、その街の本物の地図を薄く敷き、下に記録の箱を載せる(シェア画面の写真なしの初訪問と同じ)。
    private static let size: ShareCardSize = .square
    /// プレビューの高さ。お祝いのシートが縦に伸びすぎないよう抑える。
    private static let previewHeight: CGFloat = 190

    private var store: SilhouetteMapStore { environmentStore ?? fallbackStore }
    private var snapshotKey: ShareMapSnapshotStore.Key {
        ShareMapSnapshotStore.Key(id: subject.target.snapshotID, box: ShareCardMapBox.box(for: .firstVisit, size: Self.size))
    }

    var body: some View {
        let summary = summaryStore.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        let content = FirstVisitShareCardContent(
            municipalityName: subject.target.name, prefectureName: subject.target.prefectureName, progress: summary.progress,
            firstVisitDate: subject.firstVisitDate
        )
        VStack(spacing: 10) {
            Button(action: openEditor) {
                ShareCardPreview(rendered: rendered, size: Self.size)
            }
            .buttonStyle(.plain)
            .frame(height: Self.previewHeight)
            .accessibilityHint("写真や種類を変えられるシェア画面を開きます")
            Button {
                if let rendered { ShareCardActivity.present(rendered) }
            } label: {
                Label("シェアする", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .popSecondaryButton()
            .disabled(rendered == nil)
        }
        .task(id: subject.target) {
            await subject.target.loadMap(in: store)
            isMapLoaded = true
        }
        .task(id: shapeMode) {
            guard shapeMode == .location else { return }
            await subject.target.loadLocationMap(in: store)
            isLocationMapLoaded = true
        }
        .task(id: isMapLoaded) {
            guard isMapLoaded, let map = subject.target.map(in: store) else { return }
            await snapshotStore.loadBackdropIfNeeded(for: snapshotKey, map: map)
        }
        // 地図ができたとき・本物の地図が届いたとき・数が変わったときに描き直す(シェア画面の初訪問と同じ描き方)。
        .task(id: RenderKey(
            content: content, isMapLoaded: isMapLoaded, hasBackdrop: snapshotStore.backdrop(for: snapshotKey) != nil,
            boxStyle: boxStyle, shapeMode: shapeMode, isLocationMapLoaded: isLocationMapLoaded
        )) {
            guard isMapLoaded else { return }
            let map = subject.target.map(in: store)
            let model = ShareCardModel(
                subject: .firstVisit(content, map: map, highlightedCodes: map.map(subject.target.highlightedCodes(in:)) ?? []),
                size: Self.size, backdrop: snapshotStore.backdrop(for: snapshotKey), boxStyle: boxStyle,
                locationShape: shapeMode == .location ? subject.target.locationShape(in: store) : nil
            )
            rendered = ShareCardRenderer.render(model)
        }
    }

    private struct RenderKey: Hashable {
        let content: FirstVisitShareCardContent
        let isMapLoaded: Bool
        let hasBackdrop: Bool
        let boxStyle: ShareCardBoxStyle
        let shapeMode: ShareCardShapeMode
        let isLocationMapLoaded: Bool
    }
}
