import SwiftUI
import UIKit

/// カードの中の地図。本物の地図があれば薄く敷き、その上に区画を塗ったシルエットを重ねる。
///
/// 本物の地図が無い(撮っている途中・撮れなかった)ときは、これまでと同じ図形だけの地図にする。
/// どちらもシルエットは`box.contentRect`に描くので、地図が届いて描き直しても塗りの位置は動かない。
struct ShareMapCanvas: View {
    let map: SilhouetteMap?
    let visitedCodes: Set<String>
    /// 強く示す区画(都道府県の「全国の都道府県」のその県)。
    var emphasizedCodes: Set<String> = []
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
                    map: map, visitedCodes: visitedCodes, emphasizedCodes: emphasizedCodes, outlineWidth: outlineWidth,
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

/// 写真の上に描く地図。与えられた広さいっぱいに、縦横比を保って区画を塗る(本物の地図は敷かない)。
struct ShareCardPhotoMap: View {
    let map: SilhouetteMap?
    let visitedCodes: Set<String>
    var emphasizedCodes: Set<String> = []
    var outlineWidth: CGFloat = 0.6
    var placeholderSystemImage = "map.fill"

    var body: some View {
        GeometryReader { proxy in
            ShareMapCanvas(
                map: map, visitedCodes: visitedCodes, emphasizedCodes: emphasizedCodes,
                box: ShareCardMapBox(width: proxy.size.width, height: proxy.size.height, padding: 0, bottomPadding: 0),
                backdrop: nil, outlineWidth: outlineWidth, placeholderSystemImage: placeholderSystemImage,
                cornerRadius: 0, isOverPhoto: true
            )
        }
    }
}
