import SwiftUI

extension View {
    /// カードの中の箱。`app`は`popCard`(白い箱・テーマ色の枠・ずらした影)、線の版は背景を透明にして枠だけを引く。
    ///
    /// 白の線は明るい写真の上でも字と枠が読めるよう、中身ごと薄い影を落とす(`compositingGroup`で箱全体を1枚にしてから)。
    @ViewBuilder
    func shareCardBox(
        _ style: ShareCardBoxStyle,
        fill: Color = Pop.card,
        shadow: Color = Pop.shadow,
        cornerRadius: CGFloat = Pop.cornerRadius,
        shadowOffset: CGFloat = 4
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch style {
        case .app:
            popCard(fill: fill, shadow: shadow, cornerRadius: cornerRadius, shadowOffset: shadowOffset)
        case .whiteLine:
            overlay(shape.stroke(Color.white, lineWidth: 2))
                .compositingGroup()
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1)
        case .blackLine:
            overlay(shape.stroke(Color.black, lineWidth: 2))
        }
    }
}

/// 写真を敷いたカードで、箱を上・真ん中・下に置く。
///
/// - 上・下: 箱と`filler`(地図のカードなら地図、ほかは空き)を縦に並べ、箱の無い側を`filler`に譲る。
///   地図のカードで箱が地図に重ならないようにするため。
/// - 真ん中: `filler`を全体に広げ、その上の真ん中に箱を置く。
struct ShareCardBoxArrangement<Box: View, Filler: View>: View {
    let position: ShareCardBoxPosition
    var spacing: CGFloat = 12
    @ViewBuilder let box: () -> Box
    @ViewBuilder let filler: () -> Filler

    var body: some View {
        switch position {
        case .top:
            VStack(spacing: spacing) {
                box()
                filler().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .middle:
            ZStack {
                filler().frame(maxWidth: .infinity, maxHeight: .infinity)
                box()
            }
        case .bottom:
            VStack(spacing: spacing) {
                filler().frame(maxWidth: .infinity, maxHeight: .infinity)
                box()
            }
        }
    }
}
