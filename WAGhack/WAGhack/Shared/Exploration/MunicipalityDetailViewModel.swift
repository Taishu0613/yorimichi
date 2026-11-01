import Observation
import SwiftUI

/// 市区町村の詳細画面で開く対象。地図・記録の一覧・将来の道中一覧など、どこから開いても同じ形で渡す。
nonisolated struct MunicipalityDetailTarget: Hashable, Sendable {
    /// 表示している市区町村の行政区域コード(政令指定都市なら市のコード)。
    let code: String
    let prefectureName: String
    let municipalityName: String
    /// 市区町村マスタの「みどころ」の列の値。
    let spotsJSON: String

    /// マップアプリで検索するときに名前へ添える地名。同名の施設・同名の市区町村を区別するため、都道府県から書く。
    var areaName: String { prefectureName + municipalityName }
}

/// 市区町村の詳細画面の、代表写真・みどころ・みどころの写真の状態。
///
/// みどころは市区町村マスタから読むだけなので通信を待たない。写真だけを通信で取る。
/// 画面1つにつき1つ持ち(`@State`)、同じ画面の表示中は結果を使い回す。bodyの再評価やスクロールでは取り直さない。
/// 画面を開き直したときはサービス側のメモリキャッシュが効くので、同じ市区町村なら通信しない。
@Observable
final class MunicipalityDetailViewModel {
    enum SpotState: Equatable {
        case loading
        case loaded([YorimichiSpot])
    }

    /// 「もっと見る」を押す前に見せる件数。読みもののカードが遠くならないよう、最初は短くする。
    static let collapsedSpotCount = 3

    private(set) var heroPhoto: WikimediaPhoto?
    /// 代表写真を探し終えたか。探している間も、見つからなかった後も、枠にはシルエットを出す(読み込みを出し続けない)。
    private(set) var isHeroResolved = false
    private(set) var spotState: SpotState = .loading
    /// スポットのidごとの写真。写真が無いスポットは入らない(カテゴリのアイコンで代える)。
    private(set) var spotPhotos: [YorimichiSpot.ID: WikimediaPhoto] = [:]
    /// 「もっと見る」で全件を広げているか。
    var isShowingAllSpots = false

    /// 今見せるスポット。写真も、見せるものの分だけ取る。
    var visibleSpots: [YorimichiSpot] {
        guard case .loaded(let spots) = spotState else { return [] }
        return isShowingAllSpots ? spots : Array(spots.prefix(Self.collapsedSpotCount))
    }

    /// 全件のうち、まだ見せていない件数。
    var hiddenSpotCount: Int {
        guard case .loaded(let spots) = spotState else { return 0 }
        return spots.count - visibleSpots.count
    }

    /// 表示しているすべての写真と、どの写真かを示す見出し。クレジットの一覧に使う。
    /// 代表写真をスポットの写真で代えた場合は、同じ写真を1回だけ出す。
    var displayedPhotos: [CreditedPhoto] {
        var photos: [CreditedPhoto] = heroPhoto.map { [CreditedPhoto(label: "街の写真", photo: $0)] } ?? []
        for spot in visibleSpots {
            guard let photo = spotPhotos[spot.id], !photos.contains(where: { $0.photo == photo }) else { continue }
            photos.append(CreditedPhoto(label: spot.name, photo: photo))
        }
        return photos
    }

    @ObservationIgnored private var loadedTarget: MunicipalityDetailTarget?
    @ObservationIgnored private var currentTarget: MunicipalityDetailTarget?

    /// みどころをマスタから読んでから、代表写真、見せているスポットの写真の順に取る。
    func load(_ target: MunicipalityDetailTarget) async {
        guard loadedTarget != target else { return }
        loadedTarget = nil
        currentTarget = target
        spotState = .loaded(YorimichiSpot.spots(fromJSON: target.spotsJSON))

        let hero = await WikipediaImageService.shared.heroPhoto(
            prefectureName: target.prefectureName, municipalityName: target.municipalityName
        )
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            heroPhoto = hero
            isHeroResolved = true
        }

        await loadVisibleSpotPhotos()
        // 途中でキャンセルされた(画面を閉じた)ときは覚えない。次に表示されたときに続きから取り直す。
        guard !Task.isCancelled else { return }
        loadedTarget = target
    }

    /// 見せているスポットの写真を、上から1件ずつ探す(同時に投げるとWikimediaへの問い合わせが一度に増えるため)。
    /// 「もっと見る」で広げたときも呼ぶ。見つからなかった結果はサービスが覚えているので、繰り返し呼んでも問い合わせ直さない。
    func loadVisibleSpotPhotos() async {
        guard let currentTarget else { return }
        for spot in visibleSpots where spotPhotos[spot.id] == nil {
            guard let photo = await WikipediaImageService.shared.spotPhoto(
                spotName: spot.name, municipalityName: currentTarget.municipalityName
            ) else { continue }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                spotPhotos[spot.id] = photo
                // 街の写真が見つからなかったときは、その街の名所の写真を代表にする。
                if heroPhoto == nil { heroPhoto = photo }
            }
        }
    }
}
