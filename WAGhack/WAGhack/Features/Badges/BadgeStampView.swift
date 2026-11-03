import SwiftUI
import UIKit

/// バッジの丸い記念スタンプ。一覧・詳細・獲得の演出で共通に使い、直径・外周・線の太さの比率をそろえてシリーズ感を出す。
///
/// - 獲得済み: 色のある印影を少し傾けて押したように見せる。段階式はランクの色の外周と星の数で示す(色だけに頼らない)。
/// - 未獲得: 絵柄を薄い印影で残し、外側に進み具合のリングを描く。鍵のアイコンだけにはせず「次に欲しい」と思える見た目にする。
/// - 準備中: 絵柄を灰色の点線の枠で見せる。進み具合のリングは描かない。
///
/// 専用の画像がアセットに入れば(`BadgeDefinition.assetName`)、描いた絵柄の代わりにそれを使う。
/// 状態の言葉(獲得済み・未獲得)は呼び出し側が文字で添え、このビュー自体は読み上げない。
struct BadgeStampView: View {
    let definition: BadgeDefinition
    let earnedTierCount: Int
    /// 未獲得の時に外側へ描く、最初の段階までの進み具合(0...1)。
    var progressFraction: Double = 0
    var size: CGFloat = 88

    private var isEarned: Bool { earnedTierCount > 0 }
    private var rank: BadgeRank? {
        definition.isTiered ? BadgeRank(earnedTierCount: earnedTierCount) : nil
    }
    private var ringWidth: CGFloat { size * 0.045 }
    /// 進み具合のリングの分だけ内側に描くスタンプの直径。
    private var stampSize: CGFloat { size - ringWidth * 3.6 }

    var body: some View {
        ZStack {
            if !isEarned, definition.isAvailable {
                Circle()
                    .stroke(Pop.themeSoft, lineWidth: ringWidth)
                Circle()
                    .trim(from: 0, to: min(max(progressFraction, 0), 1))
                    .stroke(Pop.theme, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            stamp
                .frame(width: stampSize, height: stampSize)
        }
        .padding(ringWidth / 2)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var stamp: some View {
        ZStack {
            Circle()
                .fill(fill)
            Circle()
                .strokeBorder(outerRingColor, style: outerRingStyle)
            // 記念スタンプらしい内側の点線。
            Circle()
                .strokeBorder(
                    isEarned ? Color.white.opacity(0.75) : definition.artwork.primary.opacity(0.25),
                    style: StrokeStyle(lineWidth: stampSize * 0.018, dash: [stampSize * 0.035, stampSize * 0.03])
                )
                .padding(stampSize * 0.11)
            motif
            if let rank {
                stars(count: rank.rawValue + 1, color: rank.ringColor)
                    .offset(y: stampSize * 0.3)
            }
        }
        .compositingGroup()
        // 押したスタンプは少し傾け、まだ押していない枠とひと目で区別できるようにする。
        .rotationEffect(.degrees(isEarned ? -8 : 0))
        .shadow(color: isEarned ? definition.artwork.primary.opacity(0.35) : .clear, radius: stampSize * 0.04, y: stampSize * 0.02)
    }

    @ViewBuilder
    private var motif: some View {
        if UIImage(named: definition.assetName) != nil {
            Image(definition.assetName)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .padding(stampSize * 0.06)
                .saturation(isEarned ? 1 : 0)
                .opacity(isEarned ? 1 : 0.35)
        } else {
            Image(systemName: definition.artwork.symbolName)
                .font(.system(size: stampSize * 0.34, weight: .bold))
                .foregroundStyle(motifColor)
                .offset(y: rank == nil ? 0 : -stampSize * 0.04)
        }
    }

    private func stars(count: Int, color: Color) -> some View {
        HStack(spacing: stampSize * 0.015) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: stampSize * 0.1, weight: .black))
                    .foregroundStyle(color)
                    .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
            }
        }
    }

    private var fill: AnyShapeStyle {
        if isEarned {
            let primary = definition.artwork.primary
            return AnyShapeStyle(LinearGradient(
                colors: [primary.mix(with: .white, by: 0.15), primary.mix(with: .black, by: 0.12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
        return AnyShapeStyle(Pop.card)
    }

    private var outerRingColor: Color {
        guard isEarned else {
            return definition.isAvailable ? definition.artwork.primary.opacity(0.35) : Pop.muted.opacity(0.45)
        }
        return rank?.ringColor ?? definition.artwork.accent
    }

    private var outerRingStyle: StrokeStyle {
        let width = stampSize * (isEarned ? 0.07 : 0.03)
        // 準備中は点線の枠にして、まだ集められないことを形でも伝える。
        return definition.isAvailable ? StrokeStyle(lineWidth: width) : StrokeStyle(lineWidth: width, dash: [width * 2, width * 1.5])
    }

    private var motifColor: Color {
        if isEarned { return .white }
        return definition.isAvailable ? definition.artwork.primary.opacity(0.4) : Pop.muted.opacity(0.4)
    }
}

#Preview {
    let definitions = BadgeCatalog.all
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
            ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                BadgeStampView(
                    definition: definition,
                    earnedTierCount: index % 3 == 0 ? min(index / 3 + 1, definition.tiers.count) : 0,
                    progressFraction: 0.6
                )
            }
        }
        .padding()
    }
}
