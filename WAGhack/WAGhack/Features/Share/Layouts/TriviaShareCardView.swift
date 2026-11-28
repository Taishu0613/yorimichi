import SwiftUI
import UIKit

/// 豆知識のシェア用カード(1.8.0 (6)の見た目)。怪奇・都市伝説は図鑑と同じ夜色のカードにし、「諸説あり」を添える。
///
/// - 写真なし: 上に市区町村の形(本物の地図を薄く敷く)と名前、下に話題のカード。
/// - 写真あり(1.8.0 (10)): 写真をカードいっぱいに(暗くせず)敷き、上にその街の形を大きく(「県の中の位置」なら県の形の中で塗る)、
///   その下に名前と話題の箱。標準は(9)の名前のパネルと話題のカード、小さい箱は見出し(話題＋名前)を1行にして余白と行間を詰める。
///
/// 本文は省略しない(1.8.0 (9))。長いときは箱が伸び、それでもカードに収まらないときだけ、本文の文字を少しずつ小さくして全文を入れる
/// (`textScales`を大きい順に試し、収まる最初の大きさで描く。どれも収まらなければいちばん小さい大きさ)。
struct TriviaShareCardView: View {
    let content: TriviaShareCardContent
    let map: SilhouetteMap?
    let highlightedCodes: Set<String>
    let model: ShareCardModel

    private var layout: ShareCardSize { model.size }
    private var backdrop: ShareMapBackdrop? { model.backdrop }
    private var photo: UIImage? { model.photo }
    private var boxStyle: ShareCardBoxStyle { model.effectiveBoxStyle }
    private var isStory: Bool { layout == .story }

    /// 本文の文字の倍率。大きい順に試す。いちばん小さくても読める大きさ(縦長で約9pt)までにする。
    static let textScales: [CGFloat] = [1, 0.94, 0.88, 0.82, 0.76, 0.7, 0.64]

    var body: some View {
        ZStack {
            if let photo {
                ShareCardPhotoBackground(photo: photo, size: layout.pointSize)
            } else {
                ShareCardBackground()
            }
            ViewThatFits(in: .vertical) {
                ForEach(Self.textScales, id: \.self) { scale in
                    arrangedLayout(textScale: scale)
                }
            }
        }
        .frame(width: layout.pointSize.width, height: layout.pointSize.height)
        .clipped()
    }

    @ViewBuilder
    private func arrangedLayout(textScale: CGFloat) -> some View {
        switch (layout, photo != nil) {
        case (.story, false): storyLayout(textScale: textScale)
        case (.square, false): squareLayout(textScale: textScale)
        case (_, true): photoLayout(textScale: textScale)
        }
    }

    private func storyLayout(textScale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                pills
                nameRow(nameSize: 32, style: .app, marker: Pop.yellow, foreground: Pop.ink)
            }
            mapCanvas(box: .triviaStory)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            topicCard(fontSize: 14.5, headingSize: 20, iconSize: 32, textScale: textScale)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    private func squareLayout(textScale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    pills
                    nameRow(nameSize: 24, style: .app, marker: Pop.yellow, foreground: Pop.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                mapCanvas(box: .triviaSquare)
                    .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 3)
            }
            topicCard(fontSize: 11.5, headingSize: 15, iconSize: 24, textScale: textScale)
        }
        .padding(18)
        // 右下の角のアプリ名(`ShareCardCanvas`)に掛けない。
        .padding(.bottom, 22)
    }

    // MARK: - 写真あり(1.8.0 (10))

    /// 上にその街の形を大きく、その下に名前と話題の箱。本文が長いときは形が小さくなり、それでも収まらなければ本文の文字を小さくする。
    private func photoLayout(textScale: CGFloat) -> some View {
        ShareCardPhotoComposition(
            size: layout, adjustment: model.adjustment, spacing: isStory ? 10 : 8, minimumPolygonHeight: isStory ? 90 : 56
        ) {
            ShareCardPhotoShape(shape: model.shape, boxStyle: boxStyle)
        } box: {
            switch model.boxSize {
            case .standard:
                VStack(alignment: .leading, spacing: isStory ? 8 : 6) {
                    namePanel(nameSize: isStory ? 26 : 20, padding: isStory ? 12 : 8)
                    if isStory {
                        topicCard(fontSize: 13.5, headingSize: 18, iconSize: 28, textScale: textScale)
                    } else {
                        topicCard(fontSize: 11, headingSize: 14, iconSize: 22, textScale: textScale)
                    }
                }
            case .compact:
                compactTopicCard(textScale: textScale)
            }
        }
    }

    /// 小さい箱: 話題の見出しと名前・都道府県・訪問の印を1行にし、本文は全文のまま、余白と行間を詰める。
    private func compactTopicCard(textScale: CGFloat) -> some View {
        let baseFontSize: CGFloat = isStory ? 12.5 : 10
        let headingSize: CGFloat = isStory ? 14 : 12
        let textColor = boxStyle.primary(isLegend ? Pop.onNight : Pop.ink)
        return VStack(alignment: .leading, spacing: baseFontSize * 0.45) {
            HStack(alignment: .center, spacing: 6) {
                PopIconBadge(
                    systemImage: systemImage,
                    fill: isLegend ? Pop.legend : iconFill,
                    foreground: isLegend ? .white : Pop.inkOnAccent,
                    size: isStory ? 20 : 16
                )
                MarkerHeading(content.title, size: headingSize, marker: boxStyle.marker(isLegend ? Pop.legend : iconFill), foreground: textColor)
                Text(content.municipalityName)
                    .font(.system(size: headingSize, weight: .black))
                    .foregroundStyle(textColor)
                Spacer(minLength: 4)
                Text(compactBadgeText)
                    .font(.system(size: headingSize * 0.68, weight: .heavy, design: .rounded))
                    .foregroundStyle(boxStyle.secondary(isLegend ? Pop.onNight.opacity(0.7) : Pop.muted))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            topicText(fontSize: baseFontSize * textScale, color: textColor, lineSpacingRatio: 0.15)
            legendNote(fontSize: baseFontSize * 0.8)
        }
        .padding(isStory ? 10 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shareCardBox(
            boxStyle,
            fill: (isLegend ? Pop.night : Color.white).opacity(0.93),
            shadow: isLegend ? Pop.legend.opacity(0.6) : Pop.yellow.opacity(0.8),
            cornerRadius: 12,
            shadowOffset: 3
        )
    }

    /// 小さい箱で名前の右に添える、都道府県と訪問の印(標準の箱の2つの札と同じ中身)。
    private var compactBadgeText: String {
        let visit = content.isVisited ? "訪問済み" : "まだ行ってない"
        return content.prefectureName.isEmpty ? visit : "\(content.prefectureName) · \(visit)"
    }

    // MARK: - 部品

    /// 写真の上に置く、都道府県・訪問の印と名前のパネル。名前の長さに合わせて幅を決め、写真をなるべく隠さない。
    private func namePanel(nameSize: CGFloat, padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: padding * 0.6) {
            pills
            nameRow(nameSize: nameSize, style: boxStyle, marker: boxStyle.marker(), foreground: boxStyle.primary())
        }
        .padding(padding)
        // すりガラスは画像に書き出せないため、ほぼ白の半透明にする(初訪問のパネルと同じ)。
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.theme.opacity(0.35), shadowOffset: 3)
    }

    /// 名前。形を添えるとき(`ShareCardModel.boxShape`)は名前の左に置く。
    private func nameRow(nameSize: CGFloat, style: ShareCardBoxStyle, marker: Color, foreground: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let shape = model.boxShape {
                ShareCardBoxShape(shape: shape, boxStyle: style, side: nameSize * 1.5)
            }
            MarkerHeading(content.municipalityName, size: nameSize, marker: marker, foreground: foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func mapCanvas(box: ShareCardMapBox) -> some View {
        ShareMapCanvas(
            map: map, visitedCodes: highlightedCodes, box: box, backdrop: backdrop, outlineWidth: 1,
            placeholderSystemImage: "mappin.and.ellipse"
        )
    }

    /// 都道府県と訪問の印。正方形の細い列で横に収まらなければ縦に積む(「まだ行って…」と切れないように)。
    private var pills: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { pillItems }
            VStack(alignment: .leading, spacing: 4) { pillItems }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var pillItems: some View {
        if !content.prefectureName.isEmpty {
            PopPill(text: content.prefectureName, systemImage: "mappin", fill: Pop.themeSoft)
        }
        if content.isVisited {
            PopPill(text: "訪問済み", systemImage: "checkmark", fill: Pop.yellow)
        } else {
            PopPill(text: "まだ行ってない", systemImage: "circle.dashed", fill: Color.white)
        }
    }

    private var isLegend: Bool {
        if case .legend = content.topic { return true }
        return false
    }

    private var systemImage: String {
        switch content.topic {
        case .highlights: "sparkles"
        case .legend: "moon.stars.fill"
        case .spot: "figure.walk"
        }
    }

    /// 話題のカード。`textScale`は本文(と、この街でできることのスポット名)だけに掛ける。見出しは同じ大きさのまま。
    private func topicCard(fontSize baseFontSize: CGFloat, headingSize: CGFloat, iconSize: CGFloat, textScale: CGFloat) -> some View {
        let fontSize = baseFontSize * textScale
        let textColor = boxStyle.primary(isLegend ? Pop.onNight : Pop.ink)
        return VStack(alignment: .leading, spacing: baseFontSize * 0.7) {
            HStack(spacing: 8) {
                PopIconBadge(
                    systemImage: systemImage,
                    fill: isLegend ? Pop.legend : iconFill,
                    foreground: isLegend ? .white : Pop.inkOnAccent,
                    size: iconSize
                )
                MarkerHeading(content.title, size: headingSize, marker: boxStyle.marker(isLegend ? Pop.legend : iconFill), foreground: textColor)
            }
            topicText(fontSize: fontSize, color: textColor, lineSpacingRatio: 0.3)
            legendNote(fontSize: baseFontSize * 0.8)
        }
        .padding(baseFontSize * 1.1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shareCardBox(
            boxStyle,
            // 写真の上では写真の色が少し透けるようにする。文字が読める濃さは残す。
            fill: (isLegend ? Pop.night : Color.white).opacity(photo == nil ? 1 : 0.93),
            shadow: isLegend ? Pop.legend.opacity(0.6) : Pop.yellow.opacity(0.8),
            shadowOffset: 4
        )
    }

    /// みどころは黄色、この街でできることは図鑑の見出しと同じ水色。
    private var iconFill: Color {
        if case .spot = content.topic { return Pop.themeSoft }
        return Pop.yellow
    }

    /// 話題の本文(この街でできることはスポット名と一言)。省略しない。
    @ViewBuilder
    private func topicText(fontSize: CGFloat, color: Color, lineSpacingRatio: CGFloat) -> some View {
        switch content.topic {
        case .highlights(let text), .legend(let text):
            paragraph(text, fontSize: fontSize, color: color, lineSpacingRatio: lineSpacingRatio)
        case .spot(let name, let line):
            Text(name)
                .font(.system(size: fontSize * 1.35, weight: .black))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            if !line.isEmpty {
                paragraph(line, fontSize: fontSize * 1.1, color: color, lineSpacingRatio: lineSpacingRatio)
            }
        }
    }

    /// 伝説や噂話なので、事実と受け取られないよう注記する。
    @ViewBuilder
    private func legendNote(fontSize: CGFloat) -> some View {
        if isLegend {
            Text("※諸説あり")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(boxStyle.secondary(Pop.onNight.opacity(0.7)))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// 本文。省略せず、行数を制限しない(箱が伸びる)。大きさは`textScale`で決める。
    private func paragraph(_ text: String, fontSize: CGFloat, color: Color, lineSpacingRatio: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(color)
            .lineSpacing(fontSize * lineSpacingRatio)
            .fixedSize(horizontal: false, vertical: true)
    }
}
