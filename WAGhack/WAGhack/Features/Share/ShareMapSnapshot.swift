import MapKit
import Observation
import SwiftUI
import UIKit
import os

/// カードの中の地図の枠。大きさと、塗った区画(シルエット)を収める内側の余白を決める。
///
/// 本物の地図(MapKitのスナップショット)は枠いっぱいに敷き、シルエットは余白の内側に縦横比を保って収める。
/// 下の余白を広めに取るのは、スナップショットの左下に入るAppleマップのロゴ(帰属表示)に塗りを重ねないため。
nonisolated struct ShareCardMapBox: Hashable, Sendable {
    let size: CGSize
    let padding: CGFloat
    /// 下の余白。左下のAppleマップのロゴ(下端から約8〜22pt)より上にシルエットを収める。
    let bottomPadding: CGFloat

    init(width: CGFloat, height: CGFloat, padding: CGFloat, bottomPadding: CGFloat? = nil) {
        size = CGSize(width: width, height: height)
        self.padding = padding
        self.bottomPadding = bottomPadding ?? max(padding, Self.attributionClearance)
    }

    /// Appleマップのロゴの分として、下に空ける最小の余白(pt)。
    static let attributionClearance: CGFloat = 24

    /// シルエットを描く範囲(枠の左上が原点)。内側の余白の中に、地図の縦横比で中央に収める。
    func contentRect(aspectRatio: CGFloat) -> CGRect {
        let inner = CGRect(
            x: padding, y: padding,
            width: max(size.width - padding * 2, 1), height: max(size.height - padding - bottomPadding, 1)
        )
        return inner.fitted(aspectRatio: aspectRatio)
    }

    // MARK: - カードごとの枠(カードのレイアウトと同じ値。変えるときは両方そろえる)

    /// 全国のカード。縦長は横幅いっぱい(360 - 左右24×2)。
    static let japanStory = ShareCardMapBox(width: 312, height: 290, padding: 12)
    static let japanSquare = ShareCardMapBox(width: 176, height: 236, padding: 8)
    /// 都道府県・政令指定都市のカード。
    static let regionStory = ShareCardMapBox(width: 312, height: 300, padding: 14)
    static let regionSquare = ShareCardMapBox(width: 186, height: 236, padding: 10)
    /// 豆知識のカード。
    static let triviaStory = ShareCardMapBox(width: 312, height: 210, padding: 16)
    static let triviaSquare = ShareCardMapBox(width: 120, height: 104, padding: 8, bottomPadding: 22)
    /// 初訪問のカード(写真なし)。カード全体に地図を敷き、下半分のパネルより上に市区町村を描く。
    static let firstVisitStory = ShareCardMapBox(width: 360, height: 640, padding: 48, bottomPadding: 350)
    static let firstVisitSquare = ShareCardMapBox(width: 360, height: 360, padding: 20, bottomPadding: 222)
}

/// スナップショットを撮る範囲と、撮れた画像を置く位置の計算。状態を持たない純粋な計算なので単体テストできる。
///
/// シルエット(`SilhouetteMap`)はメルカトル図法で0〜1に正規化してあり、MapKitの`MKMapPoint`も同じ図法なので、
/// 「`geoFrame`が`contentRect`にちょうど収まる」ように枠全体の`MKMapRect`を決めれば、撮った地図とシルエットが重なる。
nonisolated enum ShareMapSnapshotGeometry {
    /// 経緯度の範囲を、MapKitの平面(Webメルカトル)の矩形にする。
    static func mapRect(of frame: GeoBoundingBox) -> MKMapRect {
        let topLeft = MKMapPoint(CLLocationCoordinate2D(latitude: frame.maxLatitude, longitude: frame.minLongitude))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(latitude: frame.minLatitude, longitude: frame.maxLongitude))
        return MKMapRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
    }

    /// 大きさ`boxSize`の枠全体に写す範囲。`geoFrame`が枠の中の`contentRect`に来るよう、外側へ同じ縮尺で広げる。
    static func snapshotMapRect(geoFrame: GeoBoundingBox, contentRect: CGRect, boxSize: CGSize) -> MKMapRect {
        let frameRect = mapRect(of: geoFrame)
        // 縦横の縮尺(地図の1ptあたりの`MKMapPoint`)。縦横比をそろえた`contentRect`なら2つは等しい。
        let scaleX = frameRect.width / max(Double(contentRect.width), .ulpOfOne)
        let scaleY = frameRect.height / max(Double(contentRect.height), .ulpOfOne)
        return MKMapRect(
            x: frameRect.minX - Double(contentRect.minX) * scaleX,
            y: frameRect.minY - Double(contentRect.minY) * scaleY,
            width: Double(boxSize.width) * scaleX,
            height: Double(boxSize.height) * scaleY
        )
    }

    /// 撮れた画像を枠のどこに置くか。
    ///
    /// MapKitは頼んだ範囲をそのまま撮るはずだが、念のため実際に`geoFrame`が写った位置(`actualContentRect`、
    /// `snapshot.point(for:)`で求めた画像の中の位置)が、シルエットを描く位置(`expectedContentRect`)に来るよう
    /// 拡大・移動する。ずれが無ければ画像は枠ぴったりに置かれ、ロゴ(帰属表示)も切れない。
    static func imageFrame(imageSize: CGSize, actualContentRect: CGRect, expectedContentRect: CGRect) -> CGRect {
        let scaleX = expectedContentRect.width / max(actualContentRect.width, .ulpOfOne)
        let scaleY = expectedContentRect.height / max(actualContentRect.height, .ulpOfOne)
        return CGRect(
            x: expectedContentRect.minX - actualContentRect.minX * scaleX,
            y: expectedContentRect.minY - actualContentRect.minY * scaleY,
            width: imageSize.width * scaleX,
            height: imageSize.height * scaleY
        )
    }

    /// 0〜1の矩形(小窓の囲みなど)を、シルエットを描く範囲の中の位置にする。
    static func rect(_ normalized: CGRect, in contentRect: CGRect) -> CGRect {
        CGRect(
            x: contentRect.minX + normalized.minX * contentRect.width,
            y: contentRect.minY + normalized.minY * contentRect.height,
            width: normalized.width * contentRect.width,
            height: normalized.height * contentRect.height
        )
    }
}

/// 撮った本物の地図の画像と、枠の中で置く位置。
struct ShareMapSnapshotImage {
    let image: UIImage
    /// 枠の左上を原点とした位置。ふつうは枠ぴったり(`ShareMapSnapshotGeometry.imageFrame`)。
    let frame: CGRect
}

/// カードの地図の下に薄く敷く本物の地図。全国のカードは沖縄の小窓の分も別に撮る。
struct ShareMapBackdrop {
    let main: ShareMapSnapshotImage
    /// 沖縄の小窓。位置は小窓の囲み(`SilhouetteMap.insetFrame`)の左上が原点。
    let inset: ShareMapSnapshotImage?
}

/// シェア画面で、カードの地図の下に敷く本物の地図(MapKitのスナップショット)を撮って持っておく。
///
/// シェア画面を開いている間だけ持ち、範囲(全国・都道府県など)と枠の大きさごとに1回だけ撮る。
/// 撮れない間・撮れなかったとき(圏外など)はカードを図形だけで描くので、呼び出し側は`backdrop(for:)`がnilでも描ける。
/// 撮る範囲はシルエットの経緯度の範囲(`SilhouetteMap.geoFrame`)だけで、訪問の記録は使わない(Appleへ送るのは地図の範囲だけ)。
@Observable
final class ShareMapSnapshotStore {
    struct Key: Hashable {
        /// 範囲を区別する文字列(「japan」「prefecture-23」など)。
        let id: String
        let box: ShareCardMapBox
    }

    private(set) var backdrops: [Key: ShareMapBackdrop] = [:]
    /// 撮り終えた(撮れなかったものも含む)キー。描き直しのきっかけに使う。
    private(set) var finishedKeys: Set<Key> = []

    @ObservationIgnored private var loadingKeys: Set<Key> = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "ShareMapSnapshot")

    /// 地図の濃さ。塗った区画が主役のまま、地名や道路がうっすら読める程度。
    static let mapOpacity: Double = 0.5

    func backdrop(for key: Key) -> ShareMapBackdrop? {
        backdrops[key]
    }

    /// 本物の地図を撮る。撮り終えている・撮っている途中なら何もしない。
    /// メルカトル図法で作っていない地図(`geoFrame`が無い)は重ねられないので撮らない。
    func loadBackdropIfNeeded(for key: Key, map: SilhouetteMap) async {
        guard backdrops[key] == nil, !finishedKeys.contains(key), !loadingKeys.contains(key),
              let geoFrame = map.geoFrame else { return }
        loadingKeys.insert(key)
        defer { loadingKeys.remove(key) }

        let contentRect = key.box.contentRect(aspectRatio: map.aspectRatio)
        do {
            let main = try await Self.snapshot(geoFrame: geoFrame, contentRect: contentRect, boxSize: key.box.size)
            var inset: ShareMapSnapshotImage?
            if let insetFrame = map.insetFrame, let insetContentFrame = map.insetContentFrame, let insetGeoFrame = map.insetGeoFrame {
                // 小窓は囲みの左上を原点にして撮る。小さいのでAppleマップのロゴは入らない(本体の地図に入る)。
                let insetBox = ShareMapSnapshotGeometry.rect(insetFrame, in: contentRect)
                let insetContent = ShareMapSnapshotGeometry.rect(insetContentFrame, in: contentRect)
                    .offsetBy(dx: -insetBox.minX, dy: -insetBox.minY)
                inset = try await Self.snapshot(geoFrame: insetGeoFrame, contentRect: insetContent, boxSize: insetBox.size)
            }
            try Task.checkCancellation()
            backdrops[key] = ShareMapBackdrop(main: main, inset: inset)
            finishedKeys.insert(key)
        } catch is CancellationError {
            // 範囲を切り替えた・画面を閉じただけ。次に同じ範囲を選んだら撮り直す。
        } catch {
            // 圏外などで撮れなくても、カードは図形だけで描けるのでユーザーには出さない。
            logger.error("地図のスナップショットを撮れませんでした(\(key.id, privacy: .public)): \(String(describing: error), privacy: .public)")
            finishedKeys.insert(key)
        }
    }

    /// 枠(`boxSize`)全体の地図を撮り、`geoFrame`が`contentRect`に来る位置を確かめて返す。
    private static func snapshot(geoFrame: GeoBoundingBox, contentRect: CGRect, boxSize: CGSize) async throws -> ShareMapSnapshotImage {
        let options = MKMapSnapshotter.Options()
        options.mapRect = ShareMapSnapshotGeometry.snapshotMapRect(geoFrame: geoFrame, contentRect: contentRect, boxSize: boxSize)
        options.size = boxSize
        // カードはライト外観・3倍で書き出すので、地図も同じにそろえる(端末の外観・画面の倍率によらない)。
        options.traitCollection = UITraitCollection { traits in
            traits.userInterfaceStyle = .light
            traits.displayScale = ShareCardLayout.renderScale
            traits.layoutDirection = .leftToRight
        }
        // 色を抑えた地図にし、お店などのアイコンは出さない(塗った区画を主役にする)。
        let configuration = MKStandardMapConfiguration(emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let topLeft = snapshot.point(for: CLLocationCoordinate2D(latitude: geoFrame.maxLatitude, longitude: geoFrame.minLongitude))
        let bottomRight = snapshot.point(for: CLLocationCoordinate2D(latitude: geoFrame.minLatitude, longitude: geoFrame.maxLongitude))
        let actualContentRect = CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
        let frame = ShareMapSnapshotGeometry.imageFrame(
            imageSize: snapshot.image.size, actualContentRect: actualContentRect, expectedContentRect: contentRect
        )
        return ShareMapSnapshotImage(image: snapshot.image, frame: frame)
    }
}

/// カードの中の地図。本物の地図があれば薄く敷き、その上に区画を塗ったシルエットを重ねる。
///
/// 本物の地図が無い(撮っている途中・撮れなかった)ときは、これまでと同じ図形だけの地図にする。
/// どちらもシルエットは`box.contentRect`に描くので、地図が届いて描き直しても塗りの位置は動かない。
struct ShareMapCanvas: View {
    let map: SilhouetteMap?
    let visitedCodes: Set<String>
    let box: ShareCardMapBox
    let backdrop: ShareMapBackdrop?
    /// 区画の隙間を埋める縁取りの太さ(`SilhouetteMapView.outlineWidth`)。
    var outlineWidth: CGFloat = 0.6
    /// 地図を読み込めなかったときに代わりに出すアイコン。
    var placeholderSystemImage = "map.fill"
    /// 枠の角の丸み。カードの地図枠(`popCard`)と同じにする。0なら丸めない(カード全体に敷くとき)。
    var cornerRadius: CGFloat = Pop.cornerRadius
    /// 写真の上に描くとき。未訪問は線だけにして写真を透かす(`backdrop`は使わない)。
    var isOverPhoto = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let map {
                let contentRect = box.contentRect(aspectRatio: map.aspectRatio)
                if let backdrop {
                    placed(backdrop.main, in: CGRect(origin: .zero, size: box.size))
                    if let inset = backdrop.inset, let insetFrame = map.insetFrame {
                        let insetBox = ShareMapSnapshotGeometry.rect(insetFrame, in: contentRect)
                        placed(inset, in: insetBox)
                    }
                }
                SilhouetteMapView(
                    map: map, visitedCodes: visitedCodes, outlineWidth: outlineWidth,
                    style: isOverPhoto ? .overPhoto : (backdrop == nil ? .solid : .overMap)
                )
                .frame(width: contentRect.width, height: contentRect.height)
                .offset(x: contentRect.minX, y: contentRect.minY)
            } else {
                Image(systemName: placeholderSystemImage)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(isOverPhoto ? Color.white.opacity(0.8) : Pop.theme.opacity(0.5))
                    .frame(width: box.size.width, height: box.size.height)
            }
        }
        .frame(width: box.size.width, height: box.size.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// 撮った地図を`container`(枠の中の位置)に置いて、薄くする。下地は白にして、カードの地の色を透かさない。
    private func placed(_ snapshot: ShareMapSnapshotImage, in container: CGRect) -> some View {
        Image(uiImage: snapshot.image)
            .resizable()
            .frame(width: snapshot.frame.width, height: snapshot.frame.height)
            .offset(x: snapshot.frame.minX, y: snapshot.frame.minY)
            .frame(width: container.width, height: container.height, alignment: .topLeading)
            .opacity(ShareMapSnapshotStore.mapOpacity)
            .background(Color.white)
            .clipped()
            .offset(x: container.minX, y: container.minY)
    }
}

extension CGRect {
    /// 縦横比を保ったまま、この矩形の中央に収まる最大の矩形。
    nonisolated func fitted(aspectRatio: CGFloat) -> CGRect {
        guard aspectRatio > 0, height > 0 else { return self }
        if width / height > aspectRatio {
            let fittedWidth = height * aspectRatio
            return CGRect(x: midX - fittedWidth / 2, y: minY, width: fittedWidth, height: height)
        } else {
            let fittedHeight = width / aspectRatio
            return CGRect(x: minX, y: midY - fittedHeight / 2, width: width, height: fittedHeight)
        }
    }
}
