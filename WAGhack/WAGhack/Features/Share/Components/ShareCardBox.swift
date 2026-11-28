import SwiftUI

extension View {
    /// カードの中の箱。`app`は`popCard`(白い箱・テーマ色の枠・ずらした影)、線の版は背景を透明にして枠だけを引く。
    ///
    /// 白の線は明るい写真の上でも字と枠が読めるよう、中身ごと薄い影を落とす(`compositingGroup`で箱全体を1枚にしてから)。
    /// 写真そのものは暗くしない(1.8.0 (8)のグラデーションは「アプリの画像感が強くなる」との声で(9)でやめた)。
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

/// 写真を敷いたカードの並び(1.8.0 (10))。上に大きな形(ポリゴン)、その下に箱。
///
/// 形は箱の残りの広さいっぱいに描く(箱を小さくするほど形が大きくなる)。箱は中身の高さのまま(本文が長ければ伸びる)。
/// 「位置を調整」でずらした分(`adjustment`)は、この並びの位置からのずれと大きさとして描く(並び自体は変えない)。
/// 箱の枠(ずらす前)は`ShareCardBoxBoundsKey`で`ShareCardCanvas`に渡し、アプリ名を箱と重ならない角に置くのに使う。
struct ShareCardPhotoComposition<Polygon: View, Box: View>: View {
    let size: ShareCardSize
    let adjustment: ShareCardAdjustment
    var spacing: CGFloat = 10
    /// 形に残す最低限の高さ。本文の長い豆知識でも形が消えないようにする(`TriviaShareCardView`は収まらなければ本文を小さくする)。
    var minimumPolygonHeight: CGFloat = 0
    @ViewBuilder let polygon: () -> Polygon
    @ViewBuilder let box: () -> Box

    var body: some View {
        let cardSize = size.pointSize
        VStack(spacing: spacing) {
            polygon()
                .frame(maxWidth: .infinity, minHeight: minimumPolygonHeight, maxHeight: .infinity)
                .adjusted(by: adjustment.shape, in: cardSize)
            box()
                .layoutPriority(1)
                .anchorPreference(key: ShareCardBoxBoundsKey.self, value: .bounds) { $0 }
                .adjusted(by: adjustment.box, in: cardSize)
        }
        // 大きさはカード(`ShareCardSize.pointSize`)の枠から受け取る。ここで高さを決めないのは、豆知識のカードが
        // `ViewThatFits`で本文の大きさを選ぶとき、この並びの本来の高さで収まるかを見るため。
        .padding(ShareCardInsets.photoContent(size))
    }
}

/// 写真を敷いたカードの箱の枠。アプリ名を箱と重ならない角に置くため(`ShareCardLogoCorner`)。
struct ShareCardBoxBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// 「位置を調整」のずれと大きさ。並びの位置は変えず、描く位置だけを動かす。
    func adjusted(by placement: ShareCardElementPlacement, in cardSize: CGSize) -> some View {
        scaleEffect(placement.scale)
            .offset(placement.offset(in: cardSize))
    }
}

/// 写真の上に大きく描く街の形(初訪問・豆知識、1.8.0 (10))。与えられた広さに縦横比を保って収める。
/// 「県の中の位置」なら県の形の中でその街を塗る(`ShareCardShapeView`)。
struct ShareCardPhotoShape: View {
    let shape: ShareCardShape
    let boxStyle: ShareCardBoxStyle

    var body: some View {
        GeometryReader { proxy in
            let fitted = Self.fittedSize(aspectRatio: shape.map?.aspectRatio ?? 1, in: proxy.size)
            ShareCardShapeView(shape: shape, boxStyle: boxStyle)
                .frame(width: fitted.width, height: fitted.height)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    static func fittedSize(aspectRatio: CGFloat, in container: CGSize) -> CGSize {
        guard aspectRatio > 0, container.width > 0, container.height > 0 else { return .zero }
        if container.width / container.height > aspectRatio {
            return CGSize(width: container.height * aspectRatio, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / aspectRatio)
    }
}

/// 小さい箱の細い進み具合の棒。`PopProgressBar`は文字の大きさに合わせた太さで細くできないため、カード用に描く。
struct ShareCardThinProgressBar: View {
    let fraction: Double
    let style: ShareCardBoxStyle
    var height: CGFloat = 5

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        Capsule()
            .fill(style.progressTrack)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(style.progressFill)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .clipShape(Capsule())
            .frame(height: height)
    }
}

/// 箱の中で名前の左に添える小さな形(`ShareCardModel.boxShape`)。
struct ShareCardBoxShape: View {
    let shape: ShareCardShape
    let boxStyle: ShareCardBoxStyle
    let side: CGFloat

    var body: some View {
        let size = ShareCardShapeView.frameSize(for: shape, side: side)
        ShareCardShapeView(shape: shape, boxStyle: boxStyle)
            .frame(width: size.width, height: size.height)
    }
}
