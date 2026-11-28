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
