import SwiftUI

/// 地図を長押しした場所に出す、区域名の吹き出し。`MapScreen`が長押しした座標に`Annotation`で置く。
///
/// 吹き出しの下端に小さな点を付け、指を置いた場所を指していると分かるようにする。
/// 訪れた区域にはチェックを添え、名前を見たついでに記録済みかも分かるようにする。
struct MapAreaNameCallout: View {
    let name: String
    let isVisited: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if isVisited {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.teal)
                        .accessibilityLabel("記録済み")
                }
                Text(name)
                    .foregroundStyle(.primary)
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            // 再記録の吹き出し(`MapRerecordCallout`)・現在地バッジと同じガラスのピルにそろえる。
            .glassEffect(.regular, in: Capsule())
            Circle()
                .fill(.teal)
                .frame(width: 8, height: 8)
                .overlay { Circle().stroke(.background, lineWidth: 2) }
        }
        // 名前は眺めるだけのもの。続けて地図を操作できるよう、タッチは地図に通す。
        .allowsHitTesting(false)
    }
}
