import SwiftUI

/// 図鑑の右上のシェアの入口のラベル(1.8.0 (7))。カードの絵と「カードにする」の文字のカプセル。
///
/// 1.8.0 (6)への声「もうちょっと目立つようにしてもいい。『カードにする』のラベルを入れる、スクロールしたらアイコンだけでもいい」
/// を受けて、絵だけのボタンから文字付きにした。読み進めたら(写真の枠を越えたら)絵だけに縮めて、本文の邪魔をしない。
/// ボタンの見た目(テーマ色のガラス)は呼び出し側で`.buttonStyle(.glassProminent)`を付ける。
struct MunicipalityShareEntryLabel: View {
    /// 絵だけに縮めているか。
    let isCollapsed: Bool
    /// 案内(TipKit)を出すときに絵を弾ませるきっかけ。
    let bounceTrigger: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.on.rectangle.angled")
                .symbolEffect(.bounce, options: .repeat(2), value: bounceTrigger)
            if !isCollapsed {
                Text("カードにする")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .fixedSize()
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
            }
        }
        // 縮めても読み上げは変えない(1.8.0 (6)と同じ「カードにしてシェア」)。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("カードにしてシェア")
    }
}

/// 図鑑の右上の入口を、絵だけに縮めるかどうか。状態を持たない計算なので単体テストできる。
nonisolated enum MunicipalityShareEntryCollapse {
    /// 縮め始めるスクロール量(pt)。街の写真の枠(`MunicipalityHeroView.height`)と、その上の余白を越えたら縮める。
    /// 写真が無い画面(住所だけの記録)は、見出しを少し越えたら縮める。
    static func threshold(hasHero: Bool, heroHeight: CGFloat, topPadding: CGFloat) -> CGFloat {
        hasHero ? heroHeight + topPadding : 44
    }

    /// `contentOffsetY`は`ScrollGeometry.contentOffset.y`、`topInset`は`contentInsets.top`(ナビゲーションバーの分)。
    /// 開いた直後は`contentOffsetY == -topInset`なので、足すと「上端から読み進めた量」になる。
    static func isCollapsed(contentOffsetY: CGFloat, topInset: CGFloat, threshold: CGFloat) -> Bool {
        contentOffsetY + topInset > threshold
    }
}
