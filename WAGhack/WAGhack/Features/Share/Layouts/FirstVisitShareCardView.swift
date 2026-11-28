import SwiftUI
import UIKit

/// 初訪問のシェア用カード(1.8.0 (6)の見た目)。
///
/// - 写真あり: 選んだ写真をカードいっぱいに(暗くせず)敷き、パネルに記録を載せる(Stravaの記録の貼り付けと同じ考え方)。
///   名前の左にその街の形(「県の中の位置」ならその県の中の位置)を添える。
/// - 写真なし: その市区町村の本物の地図を薄く敷き、形を塗って描く。地図が撮れないときは水玉の地に形だけを描く。
/// 初めて訪れた日は、記録した直後(初訪問のお祝い)から開いたときだけ載せる(`FirstVisitShareCardContent.firstVisitDate`)。
struct FirstVisitShareCardView: View {
    let content: FirstVisitShareCardContent
    let map: SilhouetteMap?
    let highlightedCodes: Set<String>
    let model: ShareCardModel

    private var layout: ShareCardSize { model.size }
    private var photo: UIImage? { model.photo }
    private var backdrop: ShareMapBackdrop? { model.backdrop }
    private var boxStyle: ShareCardBoxStyle { model.effectiveBoxStyle }
    /// 写真を敷いたときのパネルの位置。写真が無いときは下に固定する(市区町村の形をパネルより上に描くため)。
    private var boxPosition: ShareCardBoxPosition { model.boxPosition }

    /// 実際に置く位置。
    private var panelPosition: ShareCardBoxPosition { photo == nil ? .bottom : boxPosition }

    var body: some View {
        ZStack {
            background
            switch layout {
            case .story: storyLayout
            case .square: squareLayout
            }
        }
        .frame(width: layout.pointSize.width, height: layout.pointSize.height)
        .clipped()
    }

    @ViewBuilder
    private var background: some View {
        if let photo {
            ShareCardPhotoBackground(photo: photo, size: layout.pointSize)
        } else {
            ShareCardBackground()
            ShareMapCanvas(
                map: map, visitedCodes: highlightedCodes, box: layout == .story ? .firstVisitStory : .firstVisitSquare,
                backdrop: backdrop, outlineWidth: 1.2, placeholderSystemImage: "mappin.and.ellipse", cornerRadius: 0
            )
        }
    }

    /// パネルは下寄せにするが、ストーリーズの下に重なるアプリの表示(約83pt)と、
    /// 左下のAppleマップのロゴ(下端から約22pt)には掛けない。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShareCardBoxArrangement(position: panelPosition) {
                panel(nameSize: 36, countSize: 44, padding: 20)
            } filler: {
                Color.clear
            }
            ShareCardAppMark(logoSize: 30, isOverPhoto: photo != nil)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 24)
        // 写真ありは豆知識の写真のカードと同じく、ストーリーズの上に重なるアプリの表示(約60pt)を避ける。
        .padding(.top, 64)
        .padding(.bottom, 96)
    }

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            ShareCardBoxArrangement(position: panelPosition, spacing: 8) {
                panel(nameSize: 26, countSize: 30, padding: 14)
                    .frame(maxWidth: 260, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } filler: {
                Color.clear
            }
            ShareCardAppMark(logoSize: 24, isOverPhoto: photo != nil)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 30)
    }

    private func panel(nameSize: CGFloat, countSize: CGFloat, padding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: padding * 0.5) {
            HStack(spacing: 6) {
                PopPill(text: "初訪問", systemImage: "sparkles", fill: Pop.yellow)
                if !content.prefectureName.isEmpty {
                    PopPill(text: content.prefectureName, systemImage: "mappin", fill: Pop.themeSoft)
                }
            }
            HStack(alignment: .center, spacing: 10) {
                if let shape = model.boxShape {
                    ShareCardBoxShape(shape: shape, boxStyle: boxStyle, side: nameSize * 1.5)
                }
                MarkerHeading(content.municipalityName, size: nameSize, marker: boxStyle.marker(), foreground: boxStyle.primary())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if let firstVisitDate = content.firstVisitDate {
                Text("初めて訪れた日 \(FirstVisitShareCardContent.dateText(for: firstVisitDate))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(boxStyle.secondary())
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("全国で訪れた市区町村")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(boxStyle.secondary())
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(content.visitedMunicipalityCount.formatted())
                        .font(.system(size: countSize, weight: .black, design: .rounded))
                    Text("/ \(content.totalMunicipalityCount.formatted())")
                        .font(.system(size: countSize * 0.4, weight: .bold, design: .rounded))
                        .foregroundStyle(boxStyle.secondary())
                    Spacer(minLength: 4)
                    Text(content.percentageText)
                        .font(.system(size: countSize * 0.5, weight: .black, design: .rounded))
                }
                .foregroundStyle(boxStyle.primary())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 写真の上でも読めるよう、ほぼ白の半透明にする(すりガラスは画像に書き出せないため使わない)。
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.88), shadow: Pop.yellow.opacity(0.8), shadowOffset: 4)
    }
}
