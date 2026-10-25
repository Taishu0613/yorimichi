import Observation
import os
import SwiftUI

/// 市区町村の詳細画面の、通信で取ってくる部分(代表写真・よりみちスポット・スポットの写真)の状態。
///
/// 画面1つにつき1つ持ち(`@State`)、同じ画面の表示中は結果を使い回す。bodyの再評価やスクロールでは取り直さない。
/// 画面を開き直したときはサービス側のメモリキャッシュが効くので、同じ市区町村なら通信しない。
@Observable
final class MunicipalityDetailViewModel {
    enum SpotState: Equatable {
        case loading
        case loaded([YorimichiSpot])
        /// 検索できなかった(区域が無い・通信の失敗)。画面では0件と同じ控えめな案内にする。
        case unavailable
    }

    private(set) var heroPhoto: WikimediaPhoto?
    /// 代表写真を探し終えたか。探している間も、見つからなかった後も、枠にはシルエットを出す(読み込みを出し続けない)。
    private(set) var isHeroResolved = false
    private(set) var spotState: SpotState = .loading
    /// スポットのidごとの写真。写真が無いスポットは入らない(カテゴリのアイコンで代える)。
    private(set) var spotPhotos: [YorimichiSpot.ID: WikimediaPhoto] = [:]

    /// 表示しているすべての写真と、どの写真かを示す見出し。クレジットの一覧に使う。
    /// 代表写真をスポットの写真で代えた場合は、同じ写真を1回だけ出す。
    var displayedPhotos: [CreditedPhoto] {
        var photos: [CreditedPhoto] = heroPhoto.map { [CreditedPhoto(label: "街の写真", photo: $0)] } ?? []
        if case .loaded(let spots) = spotState {
            for spot in spots {
                guard let photo = spotPhotos[spot.id], !photos.contains(where: { $0.photo == photo }) else { continue }
                photos.append(CreditedPhoto(label: spot.name, photo: photo))
            }
        }
        return photos
    }

    @ObservationIgnored private var loadedTarget: MunicipalityDetailTarget?
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WAGhack", category: "SpotSearch")

    /// 代表写真を先に探し、スポットの検索はそれと並行して進める。スポットの写真は表示する順に1件ずつ探す
    /// (同時に投げるとWikimediaへの問い合わせが一度に増えるため)。
    func load(_ target: MunicipalityDetailTarget) async {
        guard loadedTarget != target else { return }
        let imageService = WikipediaImageService.shared

        async let spotsResult = searchSpots(target)
        let hero = await imageService.heroPhoto(
            prefectureName: target.prefectureName, municipalityName: target.municipalityName
        )
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            heroPhoto = hero
            isHeroResolved = true
        }

        let spots = await spotsResult
        guard !Task.isCancelled else { return }
        spotState = spots.map(SpotState.loaded) ?? .unavailable

        for spot in spots ?? [] {
            guard let photo = await imageService.spotPhoto(spotName: spot.name, municipalityName: target.municipalityName)
            else { continue }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                spotPhotos[spot.id] = photo
                // 街の写真が見つからなかったときは、その街の名所の写真を代表にする。
                if heroPhoto == nil { heroPhoto = photo }
            }
        }
        // 途中でキャンセルされた(画面を閉じた)ときは覚えない。次に表示されたときに続きから取り直す。
        loadedTarget = target
    }

    /// スポットを探す。失敗はnil(画面では「見つけられませんでした」の案内にする)。
    private func searchSpots(_ target: MunicipalityDetailTarget) async -> [YorimichiSpot]? {
        do {
            return try await MunicipalitySpotSearchService.shared.spots(for: target)
        } catch {
            logger.error("\(target.municipalityName, privacy: .public): スポットを探せませんでした \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
