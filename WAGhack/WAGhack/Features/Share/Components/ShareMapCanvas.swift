import SwiftUI
import UIKit

/// 本物の地図だけを薄く敷く(形は描かない)。写真が無いときのカードの背景にする。
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

/// まとまり・ステッカーに描く形。与えられた広さに縦横比を保って収める。
/// 描き方は文字の色に合わせる(`ShareCardTextStyle.silhouetteStyle`)。「県の中の位置」は塗らない区画を薄く塗りつぶす。
struct ShareCardShapeView: View {
    let shape: ShareCardShape
    let textStyle: ShareCardTextStyle

    var body: some View {
        if let map = shape.map {
            SilhouetteMapView(
                map: map, visitedCodes: shape.filledCodes, emphasizedCodes: shape.emphasizedCodes,
                // 小さく描くので、区画の隙間が見えないよう縁取りを細くしすぎない。
                outlineWidth: max(shape.outlineWidth, 0.5),
                style: shape.isLocation ? .location(context: textStyle.locationContext) : textStyle.silhouetteStyle
            )
        } else {
            Image(systemName: shape.placeholderSystemImage)
                .resizable()
                .scaledToFit()
                .padding(4)
                .foregroundStyle(textStyle.accent)
                .accessibilityHidden(true)
        }
    }
}

extension ShareCardTextStyle {
    /// 形の描き方。白い文字は白い線、黒い文字は黒い線、アプリの色はこれまでの灰色の地にテーマ色。
    var silhouetteStyle: SilhouetteMapView.Style {
        switch self {
        case .light: .overPhoto
        case .dark: .overLightPhoto
        case .theme: .solid
        }
    }

    /// 「県の中の位置」で、塗らない区画を薄く塗る色。
    var locationContext: Color {
        switch self {
        case .light: .white
        case .dark: .black
        case .theme: .gray
        }
    }
}
