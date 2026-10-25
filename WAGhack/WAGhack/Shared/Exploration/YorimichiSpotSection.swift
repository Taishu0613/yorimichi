import MapKit
import os
import SwiftUI

/// 「この街でできること」。よりみちスポットを最大3件、行動の言葉と一緒に並べる。
struct YorimichiSpotSection: View {
    let state: MunicipalityDetailViewModel.SpotState
    let photos: [YorimichiSpot.ID: WikimediaPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PopIconBadge(systemImage: "figure.walk", fill: Pop.themeSoft)
                MarkerHeading("この街でできること", marker: Pop.themeSoft)
            }
            switch state {
            case .loading:
                // 検索中は控えめな仮の行を2つだけ出す。名前が届いた時点で本物の行に置き換わる。
                ForEach(0..<2, id: \.self) { _ in
                    YorimichiSpotRow(spot: Self.placeholderSpot, photo: nil, isInteractive: false)
                }
                .redacted(reason: .placeholder)
                .accessibilityHidden(true)
            case .loaded(let spots) where !spots.isEmpty:
                ForEach(spots) { spot in
                    YorimichiSpotRow(spot: spot, photo: photos[spot.id])
                }
            case .loaded, .unavailable:
                Text("この街のスポットを見つけられませんでした")
                    .font(.subheadline)
                    .foregroundStyle(Pop.muted)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private static let placeholderSpot = YorimichiSpot(
        name: "スポットを探しています", latitude: 0, longitude: 0, address: nil, municipalityCode: "", experience: .landmark
    )
}

/// スポット1件の行。左に写真(無ければカテゴリのアイコン)、中央に行動の言葉・施設名・区分、右に地図の印。
/// 行全体が押せて、AppleマップかGoogleマップを選んで開く。黄色・夜色の読みものカードと競合しないよう、白い面に薄い枠だけを付ける。
struct YorimichiSpotRow: View {
    let spot: YorimichiSpot
    let photo: WikimediaPhoto?
    /// 検索中の仮の行ではfalseにして、押せないようにする。
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
                    Task { await SpotMapLauncher.openInAppleMaps(spot) }
                }
                Button("Googleマップで開く") {
                    openURL(SpotMapLauncher.googleMapsURL(for: spot))
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
                if let phrase = spot.experience.actionPhrase {
                    Text(phrase)
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
                Text(spot.experience.categoryLabel)
                    .font(.caption)
                    .foregroundStyle(Pop.muted)
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
            shape.fill(Pop.themeSoft)
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

/// スポットを外部のマップアプリで開く。アプリ内の地図・訪問の記録には触れない。
enum SpotMapLauncher {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WAGhack", category: "SpotSearch")

    /// 検索で得たAppleマップの地点idがあれば施設そのもの(営業情報や写真の載った場所カード)を開き、
    /// 無い・引けないときは座標に施設名を付けたピンを開く。
    static func openInAppleMaps(_ spot: YorimichiSpot) async {
        var mapItem: MKMapItem?
        if let identifier = spot.mapItemIdentifier.flatMap(MKMapItem.Identifier.init(rawValue:)) {
            do {
                mapItem = try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
            } catch {
                logger.error("\(spot.name, privacy: .public): 地点を引けないため座標で開きます \(error.localizedDescription, privacy: .public)")
            }
        }
        let item = mapItem ?? {
            let item = MKMapItem(location: CLLocation(latitude: spot.latitude, longitude: spot.longitude), address: nil)
            item.name = spot.name
            return item
        }()
        item.openInMaps()
    }

    /// GoogleマップのURL(公式の Maps URLs)。Googleマップのアプリがあればアプリで、無ければブラウザで開く。
    /// 座標だけでは施設名が出ないため、施設名と住所(取れていれば)で検索させる。
    static func googleMapsURL(for spot: YorimichiSpot) -> URL {
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        let query = [spot.name, spot.address].compactMap(\.self).joined(separator: " ")
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query),
        ]
        return components.url!
    }
}
