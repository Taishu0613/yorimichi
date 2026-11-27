import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import os

/// 初訪問のシェア用カードに載せるもの。「〇〇市 初訪問」と、全国で訪れた市区町村の数。
///
/// 訪れた日は載せない(カードの日付も入れない)。後から図鑑で開いても作れるため、作った日を載せると訪問日に見えてしまう。
struct FirstVisitShareCardContent: Hashable {
    let municipalityName: String
    let prefectureName: String
    let visitedMunicipalityCount: Int
    let totalMunicipalityCount: Int
    let percentageText: String

    init(municipalityName: String, prefectureName: String, progress: ExplorationCount) {
        self.municipalityName = municipalityName
        self.prefectureName = prefectureName
        visitedMunicipalityCount = progress.visited
        totalMunicipalityCount = progress.total
        percentageText = progress.percentageText
    }

    /// 画像と一緒に共有する文。
    var shareText: String {
        let headline = visitedMunicipalityCount > 0
            ? "\(municipalityName)に初訪問！ これで全国\(visitedMunicipalityCount)市区町村 #よりみち"
            : "\(municipalityName)に初訪問！ #よりみち"
        return "\(headline)\n\(ShareCardContent.appStoreURL.absoluteString)"
    }
}

/// 初訪問のシェア用カード。
///
/// - 写真あり: 選んだ写真をカードいっぱいに敷き、半透明のパネルに記録を載せる(Stravaの記録の貼り付けと同じ考え方)。
/// - 写真なし: その市区町村の本物の地図を薄く敷き、形を塗って描く。地図が撮れないときは水玉の地に形だけを描く。
struct FirstVisitShareCardView: View {
    let content: FirstVisitShareCardContent
    let layout: ShareCardLayout
    let photo: UIImage?
    let map: SilhouetteMap?
    let highlightedCodes: Set<String>
    var backdrop: ShareMapBackdrop? = nil

    var body: some View {
        ZStack {
            background
            switch layout {
            case .story: storyLayout
            case .square: squareLayout
            }
        }
        .frame(width: layout.pointSize.width, height: layout.pointSize.height)
        .clipped()
    }

    @ViewBuilder
    private var background: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: layout.pointSize.width, height: layout.pointSize.height)
                .clipped()
        } else {
            ShareCardBackground()
            ShareMapCanvas(
                map: map, visitedCodes: highlightedCodes, box: layout == .story ? .firstVisitStory : .firstVisitSquare,
                backdrop: backdrop, outlineWidth: 1.2, placeholderSystemImage: "mappin.and.ellipse", cornerRadius: 0
            )
        }
    }

    /// パネルは下寄せにするが、ストーリーズの下に重なるアプリの表示(約83pt)と、
    /// 左下のAppleマップのロゴ(下端から約22pt)には掛けない。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            panel(nameSize: 36, countSize: 44, padding: 20)
            ShareCardAppMark(logoSize: 30)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 96)
    }

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            panel(nameSize: 26, countSize: 30, padding: 14)
                .frame(maxWidth: 260, alignment: .leading)
            ShareCardAppMark(logoSize: 24)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 30)
    }

    private func panel(nameSize: CGFloat, countSize: CGFloat, padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: padding * 0.5) {
            HStack(spacing: 6) {
                PopPill(text: "初訪問", systemImage: "sparkles", fill: Pop.yellow)
                if !content.prefectureName.isEmpty {
                    PopPill(text: content.prefectureName, systemImage: "mappin", fill: Pop.themeSoft)
                }
            }
            MarkerHeading(content.municipalityName, size: nameSize)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            VStack(alignment: .leading, spacing: 0) {
                Text("全国で訪れた市区町村")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Pop.muted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(content.visitedMunicipalityCount.formatted())
                        .font(.system(size: countSize, weight: .black, design: .rounded))
                    Text("/ \(content.totalMunicipalityCount.formatted())")
                        .font(.system(size: countSize * 0.4, weight: .bold, design: .rounded))
                        .foregroundStyle(Pop.muted)
                    Spacer(minLength: 4)
                    Text(content.percentageText)
                        .font(.system(size: countSize * 0.5, weight: .black, design: .rounded))
                }
                .foregroundStyle(Pop.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 写真の上でも読めるよう、ほぼ白の半透明にする(すりガラスは画像に書き出せないため使わない)。
        .popCard(fill: Color.white.opacity(0.88), shadow: Pop.yellow.opacity(0.8), shadowOffset: 4)
    }
}

/// 初訪問をシェアする画面。市区町村の図鑑(訪問済みの街)と、初訪問のお祝いから開く。
struct FirstVisitShareSheet: View {
    let target: ShareMunicipalityTarget

    @Environment(SilhouetteMapStore.self) private var environmentStore: SilhouetteMapStore?
    @Query(sort: \Municipality.code) private var municipalities: [Municipality]
    @Query private var savedPlaces: [SavedPlace]
    @Query private var visitedPrefectures: [VisitedPrefecture]
    @State private var summaryStore = SavedPlacesStore()
    @State private var fallbackStore = SilhouetteMapStore()
    @State private var snapshotStore = ShareMapSnapshotStore()
    @State private var layout: ShareCardLayout = .story
    @State private var isMapLoaded = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    /// 写真を読み込めなかったときの案内。
    @State private var photoErrorMessage: String?
    @State private var rendered: RenderedShareCard?

    private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "FirstVisitShare")

    private var store: SilhouetteMapStore { environmentStore ?? fallbackStore }

    private var snapshotKey: ShareMapSnapshotStore.Key {
        ShareMapSnapshotStore.Key(id: target.snapshotID, box: layout == .story ? .firstVisitStory : .firstVisitSquare)
    }

    var body: some View {
        let summary = summaryStore.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        let content = FirstVisitShareCardContent(municipalityName: target.name, prefectureName: target.prefectureName, progress: summary.progress)
        ShareCardSheetScaffold(
            navigationTitle: "初訪問をシェア",
            footnote: "画像には街の名前と、訪れた市区町村の数だけが入ります。訪れた日時や場所、写真の位置情報は入りません。",
            rendered: rendered,
            layout: $layout
        ) {
            photoControls
        }
        .task(id: target) {
            await target.loadMap(in: store)
            isMapLoaded = true
        }
        .task(id: BackdropRequest(layout: layout, isMapLoaded: isMapLoaded)) {
            guard let map = target.map(in: store) else { return }
            await snapshotStore.loadBackdropIfNeeded(for: snapshotKey, map: map)
        }
        .task(id: photoItem) { await loadPhoto() }
        .task(id: RenderKey(
            content: content, layout: layout, isMapLoaded: isMapLoaded,
            hasBackdrop: snapshotStore.backdrop(for: snapshotKey) != nil, photoID: photo.map(ObjectIdentifier.init)
        )) {
            rendered = render(content: content)
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

    private struct BackdropRequest: Hashable {
        let layout: ShareCardLayout
        let isMapLoaded: Bool
    }

    private struct RenderKey: Hashable {
        let content: FirstVisitShareCardContent
        let layout: ShareCardLayout
        let isMapLoaded: Bool
        let hasBackdrop: Bool
        let photoID: ObjectIdentifier?
    }

    /// 写真があれば地図を待たずに描く。写真が無いときは形を読み込み終えてから描く。
    private func render(content: FirstVisitShareCardContent) -> RenderedShareCard? {
        guard photo != nil || isMapLoaded else { return nil }
        let map = target.map(in: store)
        let view = FirstVisitShareCardView(
            content: content, layout: layout, photo: photo, map: photo == nil ? map : nil,
            highlightedCodes: map.map(target.highlightedCodes(in:)) ?? [],
            backdrop: photo == nil ? snapshotStore.backdrop(for: snapshotKey) : nil
        )
        return ShareCardRenderer.render(view, layout: layout)
            .map { RenderedShareCard(image: $0, message: content.shareText, title: "\(target.name) 初訪問") }
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
            let target = ShareCardLayout.story.pixelSize
            let scale = min(1, max(target.width / image.size.width, target.height / image.size.height))
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
