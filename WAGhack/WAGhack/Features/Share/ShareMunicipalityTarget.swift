import Foundation

/// 豆知識・初訪問のカードに描く市区町村。
///
/// 政令指定都市そのもの(名古屋市など)は境界データに市の形が無く区の形だけがあるので、区を集めた地図
/// (`SilhouetteMapStore.shareDesignatedCityMaps`)を使う。それ以外は市区町村単体の地図(`shareMunicipalityMaps`)。
/// どちらもメルカトル図法で作るので、本物の地図を下に敷ける。
struct ShareMunicipalityTarget: Hashable {
    /// 行政区域コード(5桁)。
    let code: String
    let name: String
    let prefectureName: String
    /// 政令指定都市そのもののときの区のコード。それ以外はnil。
    let wardCodes: Set<String>?

    init(code: String, name: String, prefectureName: String, wardCodes: Set<String>? = nil) {
        self.code = code
        self.name = name
        self.prefectureName = prefectureName
        self.wardCodes = wardCodes
    }

    /// 塗る区画のコード。カードの主役なので、訪問済みかどうかに関わらず全体を塗る(訪問済みかは文字の印で示す)。
    func highlightedCodes(in map: SilhouetteMap) -> Set<String> {
        Set(map.areas.map(\.code))
    }

    func map(in store: SilhouetteMapStore) -> SilhouetteMap? {
        if wardCodes != nil {
            return store.shareDesignatedCityMaps[code]
        }
        return store.shareMunicipalityMaps[code]
    }

    func loadMap(in store: SilhouetteMapStore) async {
        if let wardCodes {
            await store.loadShareDesignatedCityMapIfNeeded(cityCode: code, wardCodes: wardCodes)
        } else {
            await store.loadShareMunicipalityMapIfNeeded(code: code)
        }
    }

    /// 本物の地図を撮り分けるときの名前。
    var snapshotID: String { "municipality-\(code)" }
}
