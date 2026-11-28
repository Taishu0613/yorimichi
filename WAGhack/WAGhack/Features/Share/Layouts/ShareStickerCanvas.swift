import SwiftUI
import UIKit

/// 「ステッカーを貼る」で作る画像(1.8.0 (8))。選んだ写真を全面に敷き、形・名前・数字のステッカーを
/// 指で動かした位置と大きさで重ね、右下か右上にアプリ名を添える。写真は暗くしない。
///
/// 1.8.0 (7)の透明なPNGのステッカーは、貼る先のアプリで重ねる手間があったので、この合成画像に置き換えた。
/// 位置と大きさはカードの座標(pt、`ShareCardSize.pointSize`)で持ち、編集画面のプレビューも書き出しもこのViewで描く。
struct ShareStickerCanvas: View {
    let photo: UIImage
    let summary: ShareCardSummary
    let shape: ShareCardShape
    let boxStyle: ShareCardBoxStyle
    let size: ShareCardSize
    let placement: ShareStickerPlacement

    private var cardSize: CGSize { size.pointSize }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ShareCardPhotoBackground(photo: photo, size: cardSize)
            ShareStickerView(summary: summary, shape: shape, boxStyle: boxStyle)
                .scaleEffect(placement.scale)
                .position(placement.center(in: cardSize))
        }
        .overlay(alignment: placement.logoCorner(in: cardSize) == .topTrailing ? .topTrailing : .bottomTrailing) {
            ShareCardAppMark(logoSize: size == .story ? 30 : 22, isOverPhoto: true)
                .fixedSize()
                .padding(ShareCardInsets.of(size))
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipped()
    }
}

/// ステッカーの位置(カードに対する中心の割合)と大きさ。割合で持つのは、縦長・正方形を切り替えても同じあたりに残すため。
nonisolated struct ShareStickerPlacement: Hashable {
    /// 中心の位置。(0, 0)が左上、(1, 1)が右下。
    var unitCenter = CGPoint(x: 0.5, y: 0.42)
    var scale: CGFloat = 1

    static let scaleRange: ClosedRange<CGFloat> = 0.4...2.6

    func center(in cardSize: CGSize) -> CGPoint {
        CGPoint(x: unitCenter.x * cardSize.width, y: unitCenter.y * cardSize.height)
    }

    /// 指で動かした分(カードのpt)だけずらす。中心はカードの外に出さない。
    func moved(by translation: CGSize, in cardSize: CGSize) -> ShareStickerPlacement {
        var moved = self
        moved.unitCenter = CGPoint(
            x: min(max(unitCenter.x + translation.width / cardSize.width, 0), 1),
            y: min(max(unitCenter.y + translation.height / cardSize.height, 0), 1)
        )
        return moved
    }

    func scaled(by magnification: CGFloat) -> ShareStickerPlacement {
        var scaled = self
        scaled.scale = min(max(scale * magnification, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        return scaled
    }

    /// アプリ名を置く角。ステッカーが下半分にあれば右上、上半分にあれば右下(ステッカーと重ねないため)。
    func logoCorner(in cardSize: CGSize) -> ShareCardLogoCorner {
        unitCenter.y >= 0.5 ? .topTrailing : .bottomTrailing
    }
}

/// ステッカー1枚。形を大きく、その下に名前と数字(制覇率)・「初訪問」・見出しのラベル。
/// 見た目はカードの箱と同じ3つ(`shareCardBox`)。アプリの色は白い箱、白の線・黒の線は枠だけ。
struct ShareStickerView: View {
    let summary: ShareCardSummary
    let shape: ShareCardShape
    let boxStyle: ShareCardBoxStyle

    private static let shapeSide: CGFloat = 170

    var body: some View {
        VStack(spacing: 6) {
            ShareCardShapeView(shape: shape, boxStyle: boxStyle)
                .frame(width: shapeWidth, height: shapeHeight)
            Text(summary.name)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(boxStyle.primary())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let stat = summary.stat {
                Text(stat.value)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(boxStyle.primary(Pop.theme))
                Text(stat.detail)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(boxStyle.secondary())
            } else {
                Text(summary.firstVisitDateText ?? summary.label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(boxStyle.secondary())
            }
        }
        .lineLimit(1)
        .padding(16)
        .frame(width: 230)
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.yellow.opacity(0.8), shadowOffset: 4)
    }

    private var shapeWidth: CGFloat { ShareCardShapeView.frameSize(for: shape, side: Self.shapeSide).width }
    private var shapeHeight: CGFloat { ShareCardShapeView.frameSize(for: shape, side: Self.shapeSide).height }
}

/// ステッカーを貼った写真で、アプリ名「よりみち」を置く角。どちらでも右上か右下。
nonisolated enum ShareCardLogoCorner: Hashable {
    case topTrailing
    case bottomTrailing
}
