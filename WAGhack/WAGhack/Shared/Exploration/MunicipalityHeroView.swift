import SwiftUI

/// 市区町村の詳細画面の先頭。街の代表写真を主役にし、隅に小さく市区町村の形を添える。
/// 写真が無い(探している間・見つからなかった・読み込めなかった)ときは、形を大きく描く。
///
/// 写真の有無で高さを変えない。写真が後から届いても下のカードが押し下げられないよう、枠の高さを先に確保する。
struct MunicipalityHeroView: View {
    let photo: WikimediaPhoto?
    /// 市区町村の形。読み込み中・政令指定都市(境界データに市の形が無い)ではnil。
    let silhouette: SilhouetteMap?

    /// 枠の高さ。標準の文字サイズでは名前と「この街でできること」の見出しまでが最初の画面に入る高さ。
    static let height: CGFloat = 172
    /// 写真の隅に添える形の大きさ。
    private static let badgeSize: CGFloat = 64

    @State private var isCreditPresented = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Pop.cornerRadius, style: .continuous)
        Group {
            if let photo {
                // 写真はfillで枠いっぱいに広げる。Color.clearに重ねるのは、写真の縦横比で枠の大きさが変わらないようにするため。
                Color.clear
                    .overlay {
                        AsyncImage(url: photo.imageURL, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .transition(.opacity)
                            default:
                                // 読み込み中・失敗は、写真の代わりに形を描く(読み込みの表示を出し続けない)。
                                largeSilhouette
                            }
                        }
                    }
                    .clipShape(shape)
                    .overlay(shape.stroke(Pop.border, lineWidth: Pop.borderWidth))
                    .overlay(alignment: .bottomLeading) {
                        if let silhouette {
                            silhouetteBadge(silhouette)
                                .padding(10)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        creditButton(for: photo)
                            .padding(8)
                    }
                    .background(shape.fill(Pop.shadow).offset(x: 4, y: 4))
                    .transition(.opacity)
            } else {
                largeSilhouette
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
    }

    /// 写真が無いときの大きな形。地図の訪問済みの市区町村と同じテーマ色の塗りと縁取りに、ずらした影を付ける。
    @ViewBuilder
    private var largeSilhouette: some View {
        if let silhouette {
            silhouetteShape(silhouette, lineWidth: 2.5, shadowOffset: 4)
                // 太い線と影が枠の端で切れないよう、内側に収める。
                .padding(6)
                .padding(.horizontal, 24)
                .accessibilityHidden(true)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private func silhouetteBadge(_ silhouette: SilhouetteMap) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return silhouetteShape(silhouette, lineWidth: 1.5, shadowOffset: 2)
            .padding(8)
            .frame(width: Self.badgeSize, height: Self.badgeSize)
            .background(Pop.card, in: shape)
            .overlay(shape.stroke(Pop.border, lineWidth: 1))
            .accessibilityHidden(true)
    }

    private func silhouetteShape(_ silhouette: SilhouetteMap, lineWidth: CGFloat, shadowOffset: CGFloat) -> some View {
        let shape = SilhouetteShape(rings: silhouette.areas.flatMap(\.rings), aspectRatio: silhouette.aspectRatio)
        return ZStack {
            shape.fill(Pop.shadow, style: FillStyle(eoFill: true))
                .offset(x: shadowOffset, y: shadowOffset)
            // 白い紙の上で地図と同じ見え方になるよう、塗りは不透明な薄い色にしてから縁取る。
            shape.fill(Pop.themeSoft, style: FillStyle(eoFill: true))
            shape.stroke(Pop.theme, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private func creditButton(for photo: WikimediaPhoto) -> some View {
        Button("写真情報", systemImage: "info") {
            isCreditPresented = true
        }
        .labelStyle(.iconOnly)
        .font(.footnote.weight(.bold))
        .foregroundStyle(Pop.ink)
        .frame(width: 32, height: 32)
        .contentShape(Circle())
        .glassEffect(.regular, in: Circle())
        .popover(isPresented: $isCreditPresented) {
            PhotoCreditView(photo: photo)
                .padding(16)
                .frame(minWidth: 260, idealWidth: 300)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// 写真1枚のクレジット(作者・ライセンス・出典)。Wikimediaの利用条件に沿って、写真の近くとページ下部の一覧から確かめられるようにする。
struct PhotoCreditView: View {
    let photo: WikimediaPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let author = photo.attribution.author {
                LabeledContent("作者", value: author)
            }
            LabeledContent("ライセンス") {
                if let licenseURL = photo.attribution.licenseURL {
                    Link(photo.attribution.licenseName, destination: licenseURL)
                } else {
                    Text(photo.attribution.licenseName)
                }
            }
            Link(destination: photo.attribution.filePageURL) {
                Label("出典(Wikimedia)を見る", systemImage: "arrow.up.right.square")
            }
        }
        .font(.footnote)
        .foregroundStyle(Pop.ink)
        .tint(Pop.theme)
    }
}

/// クレジットの一覧の1件。どの写真のクレジットかが分かるよう見出しを付ける。
struct CreditedPhoto: Identifiable {
    let label: String
    let photo: WikimediaPhoto

    var id: String { photo.id }
}

/// ページ下部の、表示している写真すべてのクレジット。
struct PhotoCreditsCard: View {
    let photos: [CreditedPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("写真について", systemImage: "camera.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Pop.ink)
            ForEach(photos) { credited in
                VStack(alignment: .leading, spacing: 4) {
                    Text(credited.label)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Pop.ink)
                    PhotoCreditView(photo: credited.photo)
                }
                if credited.id != photos.last?.id {
                    Divider()
                }
            }
            Text("写真はWikipedia・Wikimedia Commonsから表示しています。")
                .font(.caption)
                .foregroundStyle(Pop.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .popCard(shadowOffset: 0)
        .accessibilityElement(children: .contain)
    }
}
