import SwiftUI

/// 写真の上に置く「情報のまとまり」(1.8.0 (8))。大きさと中身はカードの種類で決まる(`ShareCardPanelSize`)。
///
/// 高さは中身のまま(下地も中身に合わせる)。大きなまとまりが写真の上半分に掛からないよう、本文の行数と字数で抑えている
/// (縦長は4行・約80字、正方形は3行・約56字。見出しや形の大きさを変えるときは、上半分に収まるかを見本で確かめる)。
///
/// - 小(初訪問): 形・名前(大きめの太字)・「初めて訪れた日 yyyy.MM.dd」(日が分からなければ「初訪問」)。左に寄せる。
/// - 中(制覇率): 名前・大きな数字(%)・n/N、右に行った所を塗った形を中くらいに。
/// - 大(みどころ・都市伝説・この街でできること): 見出しのラベル・形と名前・本文を数行。都市伝説は「※諸説あり」。
///
/// 形はどの大きさでも名前の文字より大きく描き、目に入るようにする。
/// 箱の枠線は引かない。アプリの色のときだけ白い下地に載せる。
struct ShareCardPanel: View {
    let model: ShareCardModel
    let maxWidth: CGFloat

    private var summary: ShareCardSummary { model.summary }
    private var style: ShareCardTextStyle { model.textStyle }
    private var isStory: Bool { model.size == .story }

    var body: some View {
        sized(content.padding(padding))
            .background {
                if style == .theme {
                    RoundedRectangle(cornerRadius: isStory ? 20 : 16, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                }
            }
            .compositingGroup()
            // 白い文字は、グラデーションの薄いところでも読めるよう薄い影を落とす。
            .shadow(color: style == .light ? .black.opacity(0.35) : .clear, radius: 2, y: 1)
    }

    private var padding: CGFloat { style == .theme ? (isStory ? 16 : 10) : 0 }

    /// 小さなまとまりは中身の大きさのまま(下地も中身に合わせる)。ほかは横幅いっぱい。
    @ViewBuilder
    private func sized(_ view: some View) -> some View {
        if model.panelSize == .small {
            view.fixedSize()
        } else {
            view
                .frame(maxWidth: maxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.panelSize {
        case .small: smallContent
        case .medium: mediumContent
        case .large: largeContent
        }
    }

    // MARK: - 小(初訪問)

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: isStory ? 8 : 6) {
            shapeView(side: isStory ? 76 : 58)
            Text(summary.name)
                .font(.system(size: fittedSize(of: summary.name, base: isStory ? 32 : 25), weight: .black))
                .foregroundStyle(style.primary)
                .lineLimit(1)
            Text(smallCaption)
                .font(.system(size: fittedSize(of: smallCaption, base: isStory ? 14 : 12), weight: .bold, design: .rounded))
                .foregroundStyle(style.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var smallCaption: String { summary.firstVisitDateText ?? summary.label }

    /// 小さなまとまりの文字の大きさ。中身の幅のまま描く(`fixedSize`)ので縮めて収める仕組みが効かない。
    /// 字数から、アプリ名と重ならない幅(`maxWidth`)に収まる大きさにする(全角は1字≒文字の大きさ、半角は約0.62倍の幅)。
    private func fittedSize(of text: String, base: CGFloat) -> CGFloat {
        let widthUnits = text.reduce(CGFloat(0)) { $0 + ($1.isASCII ? 0.62 : 1) }
        let available = maxWidth - padding * 2
        return min(base, available / max(widthUnits, 1))
    }

    // MARK: - 中(制覇率)

    private var mediumContent: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.system(size: isStory ? 22 : 18, weight: .black))
                    .foregroundStyle(style.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let stat = summary.stat {
                    Text(summary.label)
                        .font(.system(size: isStory ? 13 : 11, weight: .heavy))
                        .foregroundStyle(style.secondary)
                        .padding(.top, isStory ? 6 : 4)
                    Text(stat.value)
                        .font(.system(size: isStory ? 66 : 48, weight: .black, design: .rounded))
                        .foregroundStyle(style.accent)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(stat.detail)
                        .font(.system(size: isStory ? 16 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(style.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ShareCardShapeView(shape: model.shape, textStyle: style)
                .frame(width: isStory ? 140 : 112, height: isStory ? 150 : 116)
        }
    }

    // MARK: - 大(豆知識)

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: isStory ? 10 : 5) {
            Text(summary.label)
                .font(.system(size: isStory ? 13 : 11, weight: .heavy))
                .foregroundStyle(style.accent)
            HStack(spacing: isStory ? 12 : 10) {
                shapeView(side: isStory ? 52 : 36)
                Text(summary.name)
                    .font(.system(size: isStory ? 26 : 20, weight: .black))
                    .foregroundStyle(style.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if case .spot(let name, _)? = summary.topic?.topic {
                Text(name)
                    .font(.system(size: isStory ? 19 : 15, weight: .heavy))
                    .foregroundStyle(style.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if let topic = summary.topic {
                let size: CGFloat = isStory ? 15 : 12.5
                Text(topic.excerpt(maxLength: isStory ? 80 : 56))
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(style.primary)
                    .lineSpacing(size * 0.35)
                    .lineLimit(isStory ? 4 : 3)
                if topic.isLegend {
                    // 伝説や噂話なので、事実と受け取られないよう注記する。
                    Text("※諸説あり")
                        .font(.system(size: isStory ? 11 : 9.5, weight: .bold))
                        .foregroundStyle(style.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - 部品

    /// 形を`side`四方に、縦横比を保って左寄せで描く(細長い形でも名前の左端とそろえるため)。
    private func shapeView(side: CGFloat) -> some View {
        let aspectRatio = model.shape.map?.aspectRatio ?? 1
        let width = aspectRatio >= 1 ? side : side * max(aspectRatio, 0.45)
        let height = aspectRatio >= 1 ? side / min(aspectRatio, 2.2) : side
        return ShareCardShapeView(shape: model.shape, textStyle: style)
            .frame(width: width, height: height)
    }
}

extension ShareCardTextStyle {
    /// 名前・本文の色。
    var primary: Color {
        switch self {
        case .light: .white
        case .dark: Color(white: 0.07)
        case .theme: Pop.inkOnAccent
        }
    }

    /// 小さな見出し・日付・n/Nの色。
    var secondary: Color {
        switch self {
        case .light: .white.opacity(0.88)
        case .dark: .black.opacity(0.62)
        case .theme: Color(white: 0.38)
        }
    }

    /// 大きな数字・見出しのラベルの色。アプリの色のときだけテーマ色にする。
    var accent: Color {
        switch self {
        case .light: .white
        case .dark: Color(white: 0.07)
        case .theme: Pop.theme
        }
    }
}
