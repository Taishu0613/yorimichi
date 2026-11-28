import SwiftUI
import UIKit

/// 豆知識のシェア用カード。怪奇・都市伝説は図鑑と同じ夜色のカードにし、「諸説あり」を添える。
///
/// - 写真なし: 上に市区町村の形(本物の地図を薄く敷く)と名前、下に話題のカード。
/// - 写真あり: 写真をカードいっぱいに敷き、名前と話題をほぼ不透明のパネルに載せる(どんな写真でも読めるように)。
///   地図は出さないので、Appleマップの帰属表示も出ない。名前と話題はまとめて上・真ん中・下に置ける(`boxPosition`)。
struct TriviaStandardCard: View {
    let content: TriviaShareCardContent
    let size: ShareCardSize
    let map: SilhouetteMap?
    let highlightedCodes: Set<String>
    var backdrop: ShareMapBackdrop? = nil
    var photo: UIImage? = nil
    var boxStyle: ShareCardBoxStyle = .app
    /// 写真を敷いたときの、名前と話題の位置。写真が無いときは使わない。
    var boxPosition: ShareCardBoxPosition = .bottom

    var body: some View {
        ZStack {
            if let photo {
                ShareCardPhotoBackground(photo: photo, size: size.pointSize)
            } else {
                ShareCardBackground()
            }
            switch (size, photo != nil) {
            case (.story, false): storyLayout
            case (.square, false): squareLayout
            case (.story, true): storyPhotoLayout
            case (.square, true): squarePhotoLayout
            }
        }
        .frame(width: size.pointSize.width, height: size.pointSize.height)
        .clipped()
    }

    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                pills
                MarkerHeading(content.municipalityName, size: 32)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            mapCanvas(box: .triviaStory)
                .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 5)
            topicCard(fontSize: 14.5, headingSize: 20, iconSize: 32)
            ShareCardAppMark(logoSize: 30)
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    pills
                    MarkerHeading(content.municipalityName, size: 24)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                mapCanvas(box: .triviaSquare)
                    .popCard(shadow: Pop.theme.opacity(0.35), shadowOffset: 3)
            }
            topicCard(fontSize: 11.5, headingSize: 15, iconSize: 24)
            ShareCardAppMark(logoSize: 22)
        }
        .padding(18)
    }

    /// 写真ありの縦長。名前と話題をまとめて上・真ん中・下に置き、残りに写真を見せる。
    /// ストーリーズの上下に重なるアプリの表示(上約60pt・下約83pt)には文字を掛けない。
    private var storyPhotoLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShareCardBoxArrangement(position: boxPosition) {
                VStack(alignment: .leading, spacing: 10) {
                    namePanel(nameSize: 32, padding: 14)
                    topicCard(fontSize: 14.5, headingSize: 20, iconSize: 32)
                }
            } filler: {
                Color.clear
            }
            ShareCardAppMark(logoSize: 30, isOverPhoto: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 96)
    }

    private var squarePhotoLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShareCardBoxArrangement(position: boxPosition, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    namePanel(nameSize: 24, padding: 10)
                    topicCard(fontSize: 11.5, headingSize: 15, iconSize: 24)
                }
            } filler: {
                Color.clear
            }
            ShareCardAppMark(logoSize: 22, isOverPhoto: true)
        }
        .padding(18)
    }

    // MARK: - 部品

    /// 写真の上に置く、都道府県・訪問の印と名前のパネル。名前の長さに合わせて幅を決め、写真をなるべく隠さない。
    private func namePanel(nameSize: CGFloat, padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: padding * 0.6) {
            pills
            MarkerHeading(content.municipalityName, size: nameSize, marker: boxStyle.marker(), foreground: boxStyle.primary())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(padding)
        // すりガラスは画像に書き出せないため、ほぼ白の半透明にする(初訪問のパネルと同じ)。
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.9), shadow: Pop.theme.opacity(0.35), shadowOffset: 3)
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

    private func topicCard(fontSize: CGFloat, headingSize: CGFloat, iconSize: CGFloat) -> some View {
        let textColor = boxStyle.primary(isLegend ? Pop.onNight : Pop.ink)
        return VStack(alignment: .leading, spacing: fontSize * 0.7) {
            HStack(spacing: 8) {
                PopIconBadge(
                    systemImage: systemImage,
                    fill: isLegend ? Pop.legend : iconFill,
                    foreground: isLegend ? .white : Pop.inkOnAccent,
                    size: iconSize
                )
                MarkerHeading(content.title, size: headingSize, marker: boxStyle.marker(isLegend ? Pop.legend : iconFill), foreground: textColor)
            }
            switch content.topic {
            case .highlights(let text), .legend(let text):
                paragraph(text, fontSize: fontSize, color: textColor)
            case .spot(let name, let line):
                Text(name)
                    .font(.system(size: fontSize * 1.35, weight: .black))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !line.isEmpty {
                    paragraph(line, fontSize: fontSize * 1.1, color: textColor)
                }
            }
            if isLegend {
                // 伝説や噂話なので、事実と受け取られないよう注記する。
                Text("※諸説あり")
                    .font(.system(size: fontSize * 0.8, weight: .bold))
                    .foregroundStyle(boxStyle.secondary(Pop.onNight.opacity(0.7)))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(fontSize * 1.1)
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

    /// 本文。マスタの文はおよそ190字までなので、縮小を少しだけ許して全文を収める。
    private func paragraph(_ text: String, fontSize: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(color)
            .lineSpacing(fontSize * 0.3)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }
}
