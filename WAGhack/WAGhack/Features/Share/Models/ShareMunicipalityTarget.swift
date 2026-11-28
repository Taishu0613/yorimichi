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

    /// 都道府県コード(行政区域コードの頭2桁)。
    var prefectureCode: String { String(code.prefix(2)) }

    /// 「県の中の位置」の形(1.8.0 (8))。その県の地図(区画=市区町村)を薄く描き、この街を塗る。
    /// 県の地図では政令指定都市が区に分かれているので、市そのものなら区のコードも塗る。地図がまだ無ければnil。
    func locationShape(in store: SilhouetteMapStore) -> ShareCardShape? {
        guard let map = store.sharePrefectureMaps[prefectureCode] else { return nil }
        return ShareCardShape(
            map: map, filledCodes: (wardCodes ?? []).union([code]), outlineWidth: 0.4,
            placeholderSystemImage: "mappin.and.ellipse", isLocation: true
        )
    }

    func loadLocationMap(in store: SilhouetteMapStore) async {
        await store.loadSharePrefectureMapIfNeeded(code: prefectureCode)
    }

    /// 本物の地図を撮り分けるときの名前。
    var snapshotID: String { "municipality-\(code)" }
}
