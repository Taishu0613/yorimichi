import Foundation

/// シェア画面で選んでいるカードの中身(範囲・種類・塗り)。描き直しのきっかけにも使う(1.8.0 (7))。
///
/// 写真・箱の見た目・形・レイアウトのような「見た目」は`ShareCardModel`で持ち、ここには「何を描くか」だけを持つ。
struct ShareCardSelection: Hashable {
    var target: ShareCardTarget
    /// この街のカードの種類(`target == .town`のときだけ使う)。
    var townKind: MunicipalityShareKind
    /// この街でできることで載せるスポットの位置(`MunicipalityShareSubject.spots`の添字)。
    var spotIndex: Int
    /// 全国の地図の塗り。
    var fill: ShareCardFill
    /// 都道府県のカードで数えるもの(県内の市区町村 / 全国の都道府県)。
    var prefectureFocus: PrefectureShareFocus

    /// 選べるレイアウトを決める中身の種類。
    var subjectKind: ShareCardSubjectKind {
        switch target {
        case .town: townKind == .firstVisit ? .firstVisit : .trivia
        case .region: .map
        }
    }

    /// 都道府県を「全国の都道府県」で見せるか。
    var isNationwidePrefecture: Bool {
        if case .region(.prefecture) = target { return prefectureFocus == .nationwide }
        return false
    }

    /// 読み込む地図の範囲。全国の都道府県は日本地図(都道府県の区画)を使うので全国。この街のカードはnil。
    var mapScope: ShareScope? {
        guard case .region(let scope) = target else { return nil }
        return isNationwidePrefecture ? .japan : scope
    }
}

/// 選んだもの(`ShareCardSelection`)から、カードの中身と本物の地図の撮り方を決める。
///
/// シェア画面の状態(読み込んだ地図・読み込みを終えた範囲)を受け取るだけで、自分では状態を持たない。
/// 地図のカードと街のカードの描き分けをここに集め、シェア画面には並べ方と操作だけを残す。
struct ShareCardSubjectFactory {
    let store: SilhouetteMapStore
    /// 市区町村から開いたときのその街。
    let townSubject: MunicipalityShareSubject?
    /// 地図の読み込みを終えた範囲(失敗した範囲も含む)。
    let loadedScopes: Set<ShareScope>
    let isTownMapLoaded: Bool

    /// 描いてよいか。地図ができたか、読み込みを終えた(失敗した)範囲なら描く。
    /// 地図の有無も見るのは、同じ地図を別の画面が読み込み中だとシェア画面の読み込みがすぐ戻り、終わりを待てないため。
    func isMapReady(for selection: ShareCardSelection) -> Bool {
        guard let scope = selection.mapScope else {
            return isTownMapLoaded || townSubject.flatMap { $0.target.map(in: store) } != nil
        }
        if loadedScopes.contains(scope) { return true }
        switch scope {
        case .japan: return store.shareCardMaps != nil
        case .prefecture(let code): return store.sharePrefectureMaps[code] != nil
        case .designatedCity(let code): return store.shareDesignatedCityMaps[code] != nil
        }
    }

    /// 本物の地図を重ねるシルエット。全国は2種類の地図が同じ枠なので、市区町村の地図で範囲を決める。
    func silhouetteMap(for selection: ShareCardSelection) -> SilhouetteMap? {
        switch selection.target {
        case .town: townSubject?.target.map(in: store)
        case .region(.japan): store.shareCardMaps?.municipalityMap
        case .region(.prefecture(let code)):
            selection.isNationwidePrefecture ? store.shareCardMaps?.prefectureMap : store.sharePrefectureMaps[code]
        case .region(.designatedCity(let code)): store.shareDesignatedCityMaps[code]
        }
    }

    /// 本物の地図は範囲とレイアウトの枠(`ShareCardMapBox.backdropBox`)ごとに撮る。本物の地図を敷かないレイアウトはnil。
    func backdropKey(for selection: ShareCardSelection, size: ShareCardSize, layout: ShareCardLayout) -> ShareMapSnapshotStore.Key? {
        guard let box = ShareCardMapBox.backdropBox(for: layout, size: size) else { return nil }
        switch selection.target {
        case .town:
            guard let townSubject else { return nil }
            return ShareMapSnapshotStore.Key(id: townSubject.target.snapshotID, box: box)
        case .region(.japan):
            return ShareMapSnapshotStore.Key(id: "japan", box: box)
        case .region(.prefecture(let code)):
            // 全国の都道府県は日本地図(全国のカードと同じ範囲)で撮る。
            return ShareMapSnapshotStore.Key(id: selection.isNationwidePrefecture ? "japan" : "prefecture-\(code)", box: box)
        case .region(.designatedCity(let code)):
            return ShareMapSnapshotStore.Key(id: "city-\(code)", box: box)
        }
    }

    /// カードの中身。まだ描けない(地図の読み込み中など)ときはnil。カードの日付は描いた時点の日にする(訪問日ではない)。
    ///
    /// - この街: 写真があれば地図を待たずに描く。写真が無いときは形を読み込み終えてから描く(読み込めなければアイコンだけのカード)。
    /// - 全国: 地図を読み込めないとカードの主役が無くなるので、地図ができるまでは描かない(1.8.0 (1)と同じ)。
    /// - 都道府県・政令指定都市: 読み込みを終えたら、地図が無くても数字だけのカードを描く。
    func subject(for selection: ShareCardSelection, summary: ExplorationSummary, hasPhoto: Bool, date: Date = .now) -> ShareCardSubject? {
        switch selection.target {
        case .town:
            return townSubject(for: selection, summary: summary, hasPhoto: hasPhoto)
        case .region(let scope):
            guard isMapReady(for: selection) else { return nil }
            switch scope {
            case .japan:
                guard let maps = store.shareCardMaps else { return nil }
                return .japan(ShareCardContent(summary: summary, date: date), fill: selection.fill, maps: maps)
            case .prefecture(let code):
                guard let prefecture = summary.prefectures.first(where: { $0.code == code }) else { return nil }
                if selection.isNationwidePrefecture {
                    return .region(
                        RegionShareCardContent(nationwide: prefecture, summary: summary, date: date), map: store.shareCardMaps?.prefectureMap
                    )
                }
                return .region(RegionShareCardContent(prefecture: prefecture, date: date), map: store.sharePrefectureMaps[code])
            case .designatedCity(let code):
                guard let city = summary.designatedCities.first(where: { $0.code == code }) else { return nil }
                return .region(RegionShareCardContent(city: city, date: date), map: store.shareDesignatedCityMaps[code])
            }
        }
    }

    private func townSubject(for selection: ShareCardSelection, summary: ExplorationSummary, hasPhoto: Bool) -> ShareCardSubject? {
        // 入口は`canShare`のときだけ出すので、出せる種類が無いことは無い。万一のときは何も描かない。
        guard let townSubject, hasPhoto || isMapReady(for: selection), townSubject.availableKinds.contains(selection.townKind) else {
            return nil
        }
        let townTarget = townSubject.target
        let map = townTarget.map(in: store)
        let highlightedCodes = map.map(townTarget.highlightedCodes(in:)) ?? []
        if selection.townKind == .firstVisit {
            let content = FirstVisitShareCardContent(
                municipalityName: townTarget.name, prefectureName: townTarget.prefectureName, progress: summary.progress
            )
            return .firstVisit(content, map: map, highlightedCodes: highlightedCodes)
        }
        guard let topic = townSubject.topic(for: selection.townKind, spotIndex: selection.spotIndex) else { return nil }
        let content = TriviaShareCardContent(
            municipalityName: townTarget.name, prefectureName: townTarget.prefectureName, isVisited: townSubject.isVisited, topic: topic
        )
        return .trivia(content, map: map, highlightedCodes: highlightedCodes)
    }
}
