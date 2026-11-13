import MapKit
import SwiftUI

/// 市区町村名を地図に描くレイヤ。`Map { }`の中、`MunicipalityPuzzleLayer`の後(上)に置く。
///
/// 名前と位置は`MunicipalityPuzzleStore.municipalityNameLabels`から、訪問済みかどうかはSwiftDataの記録から受け取り、
/// ここでは描き分けるだけにする(状態は持たない)。
///
/// Appleマップの地名は文字の大きさや色を変えられないため、市区町村名はここで描く。地図の上でも読めるよう、
/// 太字にして周りを地図の地の色でフチ取る(地図アプリの地名と同じ描き方)。
/// 訪れた市区町村はテーマ色(.teal)、まだの市区町村は灰色にし、名前を見るだけでもパズルの進み具合が分かるようにする。
struct MunicipalityNameLabelLayer: MapContent {
    let labels: [MunicipalityNameLabel]
    let visitedCodes: Set<String>

    var body: some MapContent {
        ForEach(labels) { label in
            Annotation(coordinate: label.coordinate, anchor: .center) {
                MunicipalityNameLabelText(name: label.name, isVisited: visitedCodes.contains(label.code))
            } label: {
                Text(label.name)
            }
            // 標準のタイトル(マーカーの下の小さな文字)は出さない。名前は上の中身で描いている。
            .annotationTitles(.hidden)
        }
    }
}

/// 地図に載せる市区町村名の文字。
private struct MunicipalityNameLabelText: View {
    let name: String
    let isVisited: Bool

    var body: some View {
        Text(name)
            // 文字の大きさは固定にする。名前を出すかどうかを、この大きさで区域に収まるかで決めているため
            // (`MunicipalityNameLabelPolicy.pointsPerCharacter`)。地図アプリの地名も文字サイズの設定では変わらない。
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isVisited ? MunicipalityNameLabelStyle.visitedText : MunicipalityNameLabelStyle.unvisitedText)
            .lineLimit(1)
            .fixedSize()
            // ぼかしの無い影を何重かに重ねてフチ取りにする。1回だと薄く、道路や塗りの上で文字が埋もれる。
            .shadow(color: MunicipalityNameLabelStyle.halo, radius: 1)
            .shadow(color: MunicipalityNameLabelStyle.halo, radius: 1)
            .shadow(color: MunicipalityNameLabelStyle.halo, radius: 2)
            // 名前は眺めるだけのもの。ピンの選択や地図の操作の邪魔をしないよう、タップは地図に通す。
            .allowsHitTesting(false)
    }
}

/// 市区町村名の色。ダークモードでは地図の地が暗くなるため、文字を明るく、フチを暗くする。
enum MunicipalityNameLabelStyle {
    /// 訪問済み。ピースの塗り(`MunicipalityPieceStyle`)と同じtealの系統で、塗りの上でも読める濃さにしている。
    static let visitedText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.86, blue: 0.88, alpha: 1)
            : UIColor(red: 0.00, green: 0.42, blue: 0.47, alpha: 1)
    })
    /// 未訪問。地図の地名より少し控えめの灰色にして、訪問済みの名前が目立つようにする。
    static let unvisitedText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.82, alpha: 1)
            : UIColor(white: 0.30, alpha: 1)
    })
    /// フチ取り。地図の地の色に近づけ、文字だけが浮いて見えるようにする。
    static let halo = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 0.9)
            : UIColor(white: 1.0, alpha: 0.95)
    })
}
