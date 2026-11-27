import SwiftUI

/// 踏破率ヘッダーに添える小さな地図。訪問済みの区画を踏破率のバーと同じ色で塗る。
/// 日本地図(区画=都道府県)にも、都道府県の地図(区画=市区町村)にも使う。飾りなのでVoiceOverでは読み上げない。
struct SilhouetteMapView: View {
    let map: SilhouetteMap
    /// 塗る区画のコード。
    let visitedCodes: Set<String>
    /// 区画の隙間を埋める縁取りの太さ(pt)。シェア用のカードのように大きく描くときは、小さな区画が太って見えないよう細くする。
    var outlineWidth: CGFloat = 0.8
    var style: Style = .solid

    enum Style {
        /// 未訪問を灰色で塗る(これまでの見た目)。
        case solid
        /// 本物の地図の上に重ねる(シェア用のカード)。未訪問は細い線とごく薄い色だけにして、下の地図を透かす。
        case overMap
    }

    var body: some View {
        // 区画ごとにShapeを分けると数十〜百数十個の描画になるため、未訪問・訪問済みの2枚にまとめる。
        let visited = SilhouetteShape(rings: map.areas.filter { visitedCodes.contains($0.code) }.flatMap(\.rings), aspectRatio: map.aspectRatio)
        let unvisited = SilhouetteShape(rings: map.areas.filter { !visitedCodes.contains($0.code) }.flatMap(\.rings), aspectRatio: map.aspectRatio)
        ZStack {
            switch style {
            case .solid:
                // `.secondary`は色自体が半透明で、塗りと縁取りが重なる縁だけ濃くなるため、不透明な灰色で描いてからまとめて薄くする。
                outlined(unvisited, color: .gray)
                    .compositingGroup()
                    .opacity(0.45)
                outlined(visited, color: .teal)
            case .overMap:
                unvisited
                    .fill(Color.gray.opacity(0.08))
                    .overlay {
                        unvisited.stroke(Color.gray.opacity(0.55), style: StrokeStyle(lineWidth: max(outlineWidth, 0.4), lineJoin: .round))
                    }
                // 地名がうっすら透けるよう少しだけ透かす。重なる縁が濃くならないよう、まとめてから薄くする。
                outlined(visited, color: .teal)
                    .compositingGroup()
                    .opacity(0.82)
            }
            if let insetFrame = map.insetFrame {
                InsetFrameShape(frame: insetFrame, aspectRatio: map.aspectRatio)
                    .stroke(style == .solid ? AnyShapeStyle(.secondary) : AnyShapeStyle(Pop.border), lineWidth: style == .solid ? 0.5 : 1)
            }
        }
        .accessibilityHidden(true)
    }

    /// 区画ごとに別々に間引いて角を丸めているため(丸めると形がわずかに内側へ縮む)、隣り合う区画の間に隙間ができる。
    /// 同じ色の線で縁取って隙間を埋める。
    private func outlined(_ shape: SilhouetteShape, color: Color) -> some View {
        shape
            .fill(color)
            .overlay {
                shape.stroke(color, style: StrokeStyle(lineWidth: outlineWidth, lineJoin: .round))
            }
    }
}

/// 市区町村詳細で大きく描く、形の縁取りだけの表示。
/// その画面の主役の市区町村なので、訪問済みかどうかに関わらずアプリのテーマ色で描く。飾りなのでVoiceOverでは読み上げない。
struct SilhouetteOutlineView: View {
    let map: SilhouetteMap

    var body: some View {
        SilhouetteShape(rings: map.areas.flatMap(\.rings), aspectRatio: map.aspectRatio)
            .stroke(.teal, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            // ページから少し浮いて見えるよう、線と同じ色のごく淡い影を落とす。
            .shadow(color: .teal.opacity(0.3), radius: 6, y: 3)
            // 太い線が枠の端で切れないよう、線の太さの半分以上内側に収める。
            .padding(2)
            .accessibilityHidden(true)
    }
}

/// 日本地図の沖縄の小窓を囲む角丸の枠。本体と縮尺が違うことを示す。
private struct InsetFrameShape: Shape {
    let frame: CGRect
    let aspectRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let fitted = rect.fitted(aspectRatio: aspectRatio)
        let insetRect = CGRect(
            x: fitted.minX + frame.minX * fitted.width,
            y: fitted.minY + frame.minY * fitted.height,
            width: frame.width * fitted.width,
            height: frame.height * fitted.height
        )
        return Path(roundedRect: insetRect, cornerRadius: 2)
    }
}

/// 0〜1に正規化した輪を、縦横比を保ったまま枠の中央に収めて描く。
///
/// 頂点をそのまま直線で結ばず、隣り合う頂点の中点どうしを頂点を制御点とする曲線でつなぐ。
/// 間引いてできた尖った角が丸くなり、粗い形でも柔らかく見える。
struct SilhouetteShape: Shape {
    let rings: [[CGPoint]]
    let aspectRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let fitted = rect.fitted(aspectRatio: aspectRatio)
        var path = Path()
        for ring in rings {
            addSmoothedRing(ring.map { point in
                CGPoint(x: fitted.minX + point.x * fitted.width, y: fitted.minY + point.y * fitted.height)
            }, to: &path)
        }
        return path
    }

    private func addSmoothedRing(_ ring: [CGPoint], to path: inout Path) {
        // 輪は始点=終点で閉じているので、重複する終点を除いた頂点で一周する。
        var vertices = ring
        if vertices.count > 1, vertices.first == vertices.last {
            vertices.removeLast()
        }
        guard vertices.count >= 3 else { return }

        func midpoint(_ index: Int) -> CGPoint {
            let current = vertices[index]
            let next = vertices[(index + 1) % vertices.count]
            return CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
        }

        path.move(to: midpoint(vertices.count - 1))
        for index in vertices.indices {
            path.addQuadCurve(to: midpoint(index), control: vertices[index])
        }
        path.closeSubpath()
    }
}
