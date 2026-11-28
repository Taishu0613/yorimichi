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
    /// 写真の上に描くときの形の描き方。箱の見た目に合わせる(`ShareCardBoxStyle.silhouetteStyle`)。
    var overPhotoStyle: SilhouetteMapView.Style = .overPhoto

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
                    style: isOverPhoto ? overPhotoStyle : (backdrop == nil ? .solid : .overMap)
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

/// 本物の地図だけを薄く敷く(形は描かない)。写真を敷くレイアウトで、写真がまだ無いときの背景にする。
struct ShareMapBackdropView: View {
    let backdrop: ShareMapBackdrop
    let box: ShareCardMapBox

    var body: some View {
        Image(uiImage: backdrop.main.image)
            .resizable()
            .frame(width: backdrop.main.frame.width, height: backdrop.main.frame.height)
            .offset(x: backdrop.main.frame.minX, y: backdrop.main.frame.minY)
            .frame(width: box.size.width, height: box.size.height, alignment: .topLeading)
            .opacity(ShareMapSnapshotStore.mapOpacity)
            .background(Color.white)
            .clipped()
    }
}

/// 小さな形(帯・余白・見出しに添える印)と、ステッカー・数字の形。与えられた広さに縦横比を保って収める。
struct ShareCardShapeView: View {
    let shape: ShareCardShape
    var style: SilhouetteMapView.Style = .solid
    /// 小さく描くときは縁取りを細くしすぎない(区画の隙間が見えないよう、最低でも0.5pt)。
    var outlineWidth: CGFloat? = nil

    var body: some View {
        if let map = shape.map {
            SilhouetteMapView(
                map: map, visitedCodes: shape.filledCodes, emphasizedCodes: shape.emphasizedCodes,
                outlineWidth: outlineWidth ?? max(shape.outlineWidth, 0.5), style: style
            )
        } else {
            Image(systemName: shape.placeholderSystemImage)
                .resizable()
                .scaledToFit()
                .padding(4)
                .foregroundStyle(style == .solid ? Pop.theme : Color.white)
                .accessibilityHidden(true)
        }
    }
}

extension ShareCardBoxStyle {
    /// 箱の見た目に合わせた形の描き方。白の線は写真の上の白い線、黒の線は明るい写真の上の黒い線。
    var silhouetteStyle: SilhouetteMapView.Style {
        switch self {
        case .app: .solid
        case .whiteLine: .overPhoto
        case .blackLine: .overLightPhoto
        }
    }
}
