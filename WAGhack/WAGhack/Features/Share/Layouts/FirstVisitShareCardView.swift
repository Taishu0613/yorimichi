import SwiftUI
import UIKit

/// 初訪問のシェア用カード。
///
/// - 写真あり(1.8.0 (10)): 選んだ写真をカードいっぱいに(暗くせず)敷き、上にその街の形を大きく
///   (「県の中の位置」なら県の形の中でその街を塗る)、その下に記録の箱(標準・小さい箱)。
/// - 写真なし((6)の見た目): その市区町村の本物の地図を薄く敷き、形を塗って描く。地図が撮れないときは水玉の地に形だけを描く。
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
    private var isStory: Bool { layout == .story }

    var body: some View {
        ZStack {
            background
            if photo != nil {
                photoLayout
            } else {
                switch layout {
                case .story: storyLayout
                case .square: squareLayout
                }
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
                map: map, visitedCodes: highlightedCodes, box: isStory ? .firstVisitStory : .firstVisitSquare,
                backdrop: backdrop, outlineWidth: 1.2, placeholderSystemImage: "mappin.and.ellipse", cornerRadius: 0
            )
        }
    }

    // MARK: - 写真なし

    /// パネルは下寄せにするが、ストーリーズの下に重なるアプリの表示(約83pt)と、
    /// 左下のAppleマップのロゴ(下端から約22pt)には掛けない。
    private var storyLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            panel(nameSize: 36, countSize: 44, padding: 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 96)
    }

    private var squareLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            panel(nameSize: 26, countSize: 30, padding: 14)
                .frame(maxWidth: 260, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        // 右下の角のアプリ名(`ShareCardCanvas`)に掛けない。
        .padding(.bottom, 44)
    }

    // MARK: - 写真あり(1.8.0 (10))

    private var photoLayout: some View {
        ShareCardPhotoComposition(size: layout, adjustment: model.adjustment, spacing: isStory ? 12 : 8) {
            ShareCardPhotoShape(shape: model.shape, boxStyle: boxStyle)
        } box: {
            switch model.boxSize {
            case .standard:
                if isStory {
                    panel(nameSize: 30, countSize: 34, padding: 14)
                } else {
                    panel(nameSize: 22, countSize: 24, padding: 10)
                }
            case .compact:
                compactPanel
            }
        }
    }

    /// 小さい箱: 名前の下に「初訪問 · 県 · 日付 · 全国の数」を小さな文字で1行にまとめる(情報は減らさない)。
    private var compactPanel: some View {
        VStack(alignment: .leading, spacing: isStory ? 3 : 2) {
            MarkerHeading(content.municipalityName, size: isStory ? 24 : 19, marker: boxStyle.marker(), foreground: boxStyle.primary())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(boxStyle.primary(Pop.theme))
                Text(content.compactSummaryText())
                    .foregroundStyle(boxStyle.secondary())
                    .monospacedDigit()
            }
            .font(.system(size: isStory ? 11 : 9.5, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        // 幅は中身に合わせる(記録の1行が読める大きさで収まる幅。カードの幅を超えるときだけ字を少し縮める)。
        .padding(isStory ? 10 : 8)
        .shareCardBox(boxStyle, fill: Color.white.opacity(0.88), shadow: Pop.yellow.opacity(0.8), cornerRadius: 12, shadowOffset: 3)
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
