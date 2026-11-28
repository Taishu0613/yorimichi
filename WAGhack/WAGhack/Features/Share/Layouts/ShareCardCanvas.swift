import SwiftUI

/// カード1枚を描く(1.8.0 (8))。どのカードもここを通る(`ShareCardRenderer.render(_:)`)。
///
/// 重ね方はいつも同じ:
/// 1. 全面の写真(無ければ本物の地図を薄く、撮れるまでは水玉の地)
/// 2. 文字を読めるようにする層(白い文字はまとまりの側から暗くするグラデーション、黒い文字は写真を白で薄める)
/// 3. まとまり(`ShareCardPanel`)1つを上か下に
/// 4. 右上か右下の角にアプリ名(まとまりと重ならない方。`ShareCardPanelSize.logoCorner`)
///
/// まとまりの大きさと中身はカードの種類で決まるので、ここには種類ごとの描き分けを置かない。
struct ShareCardCanvas: View {
    let model: ShareCardModel

    private var cardSize: CGSize { model.size.pointSize }
    private var insets: EdgeInsets { ShareCardInsets.of(model.size) }

    var body: some View {
        ZStack {
            ShareCardPhotoOrMapBackground(
                photo: model.photo, backdrop: model.backdrop, box: ShareCardMapBox.backdropBox(for: model.size), size: cardSize
            )
            ShareCardReadabilityLayer(
                textStyle: model.textStyle, panelSize: model.panelSize, position: model.panelPosition, logoCorner: model.logoCorner
            )
            VStack(spacing: 0) {
                if model.panelPosition == .bottom { Spacer(minLength: 0) }
                ShareCardPanel(model: model, maxWidth: panelMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if model.panelPosition == .top { Spacer(minLength: 0) }
            }
            .padding(insets)
        }
        .overlay(alignment: model.logoCorner == .topTrailing ? .topTrailing : .bottomTrailing) {
            ShareCardLogoMark(size: model.size == .story ? 24 : 20, textStyle: model.textStyle)
                .padding(insets)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipped()
    }

    /// 小さなまとまりは、同じ側の右の角のアプリ名と重ならない幅にする。
    private var panelMaxWidth: CGFloat {
        let full = cardSize.width - insets.leading - insets.trailing
        guard model.panelSize == .small else { return full }
        return full - (model.size == .story ? 104 : 92)
    }
}

/// 文字を読めるようにする層。
///
/// - 白い文字: まとまりの側から暗くするグラデーション。まとまりが大きいほど長く伸ばす。アプリ名が反対側の角にあるときは、
///   その側にも短く薄いグラデーションを足す(明るい空の上でも読めるように)。
/// - 黒い文字: 写真全体を白で薄める。
/// - アプリの色: まとまりを白い下地に載せるので、写真はそのまま。
struct ShareCardReadabilityLayer: View {
    let textStyle: ShareCardTextStyle
    let panelSize: ShareCardPanelSize
    let position: ShareCardPanelPosition
    let logoCorner: ShareCardLogoCorner

    var body: some View {
        switch textStyle {
        case .light:
            ZStack {
                gradient(from: position == .bottom ? .bottom : .top, length: panelGradientLength, opacity: 0.74)
                let logoEdge: VerticalEdge = logoCorner == .topTrailing ? .top : .bottom
                let panelEdge: VerticalEdge = position == .top ? .top : .bottom
                if logoEdge != panelEdge {
                    gradient(from: logoEdge == .top ? .top : .bottom, length: 0.2, opacity: 0.36)
                }
            }
        case .dark:
            Color.white.opacity(0.58)
        case .theme:
            Color.clear
        }
    }

    /// カードの高さに対する、まとまりの側のグラデーションの長さ。
    private var panelGradientLength: CGFloat {
        switch panelSize {
        case .small: 0.45
        case .medium: 0.55
        case .large: 0.7
        }
    }

    private func gradient(from edge: UnitPoint, length: CGFloat, opacity: Double) -> some View {
        let end = edge == .bottom ? UnitPoint(x: 0.5, y: 1 - length) : UnitPoint(x: 0.5, y: length)
        return LinearGradient(
            stops: [
                .init(color: .black.opacity(opacity), location: 0),
                .init(color: .black.opacity(opacity * 0.7), location: 0.5),
                .init(color: .clear, location: 1),
            ],
            startPoint: edge, endPoint: end
        )
    }
}
