import SwiftUI

/// 「この街でできること」。AIが総合評価したマスタのみどころを、行動の言葉と一緒に順位の順に並べる。
/// 最初は上位の数件だけを見せ、「もっと見る」で最大10件まで広げる。
struct YorimichiSpotSection: View {
    let state: MunicipalityDetailViewModel.SpotState
    let visibleSpots: [YorimichiSpot]
    let hiddenSpotCount: Int
    let photos: [YorimichiSpot.ID: WikimediaPhoto]
    /// マップアプリで検索するときに名前へ添える地名。
    let areaName: String
    @Binding var isShowingAll: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PopIconBadge(systemImage: "figure.walk", fill: Pop.themeSoft)
                MarkerHeading("この街でできること", marker: Pop.themeSoft)
            }
            switch state {
            case .loading:
                // マスタを読む一瞬だけ、行の分の場所を確保する。
                YorimichiSpotRow(spot: Self.placeholderSpot, photo: nil, areaName: "", isInteractive: false)
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)
            case .loaded(let spots) where spots.isEmpty:
                Text("この街のスポットを見つけられませんでした")
                    .font(.subheadline)
                    .foregroundStyle(Pop.muted)
            case .loaded(let spots):
                ForEach(visibleSpots) { spot in
                    YorimichiSpotRow(spot: spot, photo: photos[spot.id], areaName: areaName)
                }
                if spots.count > MunicipalityDetailViewModel.collapsedSpotCount {
                    Button {
                        isShowingAll.toggle()
                    } label: {
                        Label(
                            isShowingAll ? "閉じる" : "もっと見る(あと\(hiddenSpotCount)件)",
                            systemImage: isShowingAll ? "chevron.up" : "chevron.down"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Pop.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private static let placeholderSpot = YorimichiSpot(
        rank: 0, name: "みどころを読み込んでいます", experience: .landmark, action: nil, reason: "みどころを読み込んでいます"
    )
}

/// スポット1件の行。左に写真(無ければカテゴリのアイコン)、中央に行動の言葉・施設名・おすすめの理由、右に地図の印。
/// 行全体が押せて、AppleマップかGoogleマップを選んで開く。黄色・夜色の読みものカードと競合しないよう、白い面に薄い枠だけを付ける。
struct YorimichiSpotRow: View {
    let spot: YorimichiSpot
    let photo: WikimediaPhoto?
    let areaName: String
    /// 読み込み中の仮の行ではfalseにして、押せないようにする。
    var isInteractive = true

    @ScaledMetric(relativeTo: .body) private var thumbnailSize: CGFloat = 64
    @State private var isMapChoicePresented = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        if isInteractive {
            Button {
                isMapChoicePresented = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("マップアプリでこの場所を開きます")
            .confirmationDialog(spot.name, isPresented: $isMapChoicePresented, titleVisibility: .visible) {
                Button("Appleマップで開く") {
                    openURL(SpotMapLauncher.appleMapsURL(for: spot, in: areaName))
                }
                Button("Googleマップで開く") {
                    openURL(SpotMapLauncher.googleMapsURL(for: spot, in: areaName))
                }
            }
        } else {
            content
        }
    }

    private var content: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                // 行動の言葉を決められない施設は、無理に体験を言い切らず施設名を主にする。
                if let action = spot.displayAction {
                    Text(action)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Pop.ink)
                    Text(spot.name)
                        .font(.subheadline)
                        .foregroundStyle(Pop.ink)
                } else {
                    Text(spot.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Pop.ink)
                }
                Text(spot.reason ?? spot.experience.categoryLabel)
                    .font(.caption)
                    .foregroundStyle(Pop.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isInteractive {
                Image(systemName: "map.fill")
                    .font(.subheadline)
                    .foregroundStyle(Pop.theme)
                    .accessibilityHidden(true)
            }
        }
        .padding(10)
        .background(Pop.card, in: shape)
        .overlay(shape.stroke(Pop.border, lineWidth: 1))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
    }

    /// 写真の読み込み前後で行の高さが変わらないよう、枠の大きさは固定にする。
    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            shape.fill(Pop.themeTint)
            Image(systemName: spot.experience.systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(Pop.theme)
            if let photo {
                AsyncImage(url: photo.imageURL, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .transition(.opacity)
                    } else {
                        // 読み込み中・失敗はアイコンのまま見せる。
                        Color.clear
                    }
                }
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// スポットを開くマップアプリのURL。アプリ内の地図・訪問の記録には触れない。
/// マスタに座標を持たないので、どちらも「名前＋地名」で検索させる。
nonisolated enum SpotMapLauncher {
    /// Appleマップのリンク。iPhoneではマップアプリで開く。
    static func appleMapsURL(for spot: YorimichiSpot, in areaName: String) -> URL {
        url("https://maps.apple.com/", queryItems: [URLQueryItem(name: "q", value: query(for: spot, in: areaName))])
    }

    /// GoogleマップのURL(公式の Maps URLs)。Googleマップのアプリがあればアプリで、無ければブラウザで開く。
    static func googleMapsURL(for spot: YorimichiSpot, in areaName: String) -> URL {
        url("https://www.google.com/maps/search/", queryItems: [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query(for: spot, in: areaName)),
        ])
    }

    private static func query(for spot: YorimichiSpot, in areaName: String) -> String {
        "\(spot.name) \(areaName)"
    }

    private static func url(_ base: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(string: base)!
        components.queryItems = queryItems
        return components.url!
    }
}
