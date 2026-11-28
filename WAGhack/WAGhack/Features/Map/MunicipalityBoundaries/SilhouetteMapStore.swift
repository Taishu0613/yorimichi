import Foundation
import Observation
import os

/// 踏破率の表示に添える小さな地図(日本地図・都道府県を市区町村に分けた地図・市区町村単体の地図)を用意する。
///
/// - 日本地図: 全国の都道府県ファイル(LOD0)を1回だけ読んで作る。
/// - 都道府県の地図: その県の市区町村ファイル(LOD1)だけを、必要になったときに読んで作る。
/// - 市区町村の地図: 詳細画面で大きく描くため、その県の最も細かい市区町村ファイル(LOD3)から作る。
///
/// 作った地図は小さい(数百〜数千点)ので保持し、同じ県・市区町村に戻ったときは読み直さない。
/// 訪問済みかどうかはここでは持たない(塗り分けは描画側が`ExplorationSummary`から決める)。
/// `MapScreen`が所有し、シート内の画面へはenvironmentで渡す。
@Observable
final class SilhouetteMapStore {
    private(set) var japanMap: SilhouetteMap?
    /// 都道府県コード(2桁)ごとの、市区町村に分けた地図。
    private(set) var prefectureMaps: [String: SilhouetteMap] = [:]
    /// 行政区域コード(5桁)ごとの、市区町村単体の地図。
    private(set) var municipalityMaps: [String: SilhouetteMap] = [:]

    /// シェア用のカードに大きく描く日本地図。旅の記録の「地図をシェア」を開いたときにだけ読む。
    private(set) var shareCardMaps: ShareCardMaps?

    /// シェア用のカードに大きく描く、都道府県(区画=市区町村)の地図。都道府県コード(2桁)ごと。
    private(set) var sharePrefectureMaps: [String: SilhouetteMap] = [:]
    /// シェア用のカードに大きく描く、政令指定都市(区画=区)の地図。市そのものの行政区域コード(5桁)ごと。
    private(set) var shareDesignatedCityMaps: [String: SilhouetteMap] = [:]
    /// シェア用のカード(豆知識・初訪問)に描く、市区町村単体の地図。行政区域コード(5桁)ごと。
    private(set) var shareMunicipalityMaps: [String: SilhouetteMap] = [:]

    @ObservationIgnored private var loadingKeys: Set<String> = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "SilhouetteMap")

    /// 踏破率ヘッダーでの描画サイズ(pt)。
    static let headerMapSize: CGFloat = 56
    /// 旅の記録・都道府県画面の進捗の隣での描画サイズ(pt)。
    static let progressMapSize: CGFloat = 96
    /// 日本地図・都道府県の地図を間引く基準の大きさ(pt)。ヘッダーより大きい進捗の隣でも粗く見えないよう、大きい方に合わせる。
    private static let areaMapResolution = progressMapSize
    /// 市区町村の詳細画面で大きく描くときの基準の大きさ(pt)。画面幅いっぱいに描いても粗く見えない細かさ。
    private static let municipalityMapResolution: CGFloat = 320
    /// シェア用のカードの地図を間引く基準の大きさ(pt)。カードは横360pt(3倍で1080px)で描き、地図はほぼ横幅いっぱいになる。
    static let shareCardMapResolution: CGFloat = 360

    /// 都道府県の地図に使うLOD。LOD0(2km間引き)では小さな県の市区町村が潰れるため、1段細かいLOD1(500m)にする。
    /// 1県1ファイルで最大でも約1MB。
    private static let prefectureLOD = 1

    /// 日本地図を用意する。読み込み済み・読み込み中なら何もしない。
    func loadJapanMapIfNeeded() async {
        guard japanMap == nil else { return }
        await load(key: "japan") { repository, manifest in
            let selector = BoundaryLODSelector(transitions: manifest.lodTransitions)
            // 最も粗いLODは全国1ファイルなので、47県を1回の読み込みで揃えられる。
            let files = manifest.files(in: .prefectures, lod: selector.coarsestLOD, intersecting: Self.wholeWorld)
            // 日本地図では約15km未満の島は1pt前後にしかならず描かないので、デコード直後に捨ててメモリを抑える。
            let prefectures = try await repository.boundaries(
                in: files, pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 1_500_000)
            )
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.areaMapResolution)
            // 間引きは全国で数十万頂点を舐めるので、メインスレッドの外で行う。
            let map = await Task.detached(priority: .utility) { builder.japanMap(of: prefectures) }.value
            try Task.checkCancellation()
            self.japanMap = map
        }
    }

    /// シェア用のカードに大きく描く日本地図を用意する(都道府県を区画にした地図と、全国の市区町村を区画にした地図)。
    /// 読み込み済み・読み込み中なら何もしない。
    ///
    /// 市区町村の地図には、最も粗いLOD0(2km間引き)の全国1ファイル(約1,900区画・約700KB)を使う。
    /// カードの地図は横360pt(書き出しで1080px)ほどで、1pt≒5kmなので2km間引きで十分に滑らか。
    /// 都道府県の地図は進捗の隣の`japanMap`(96pt基準)を引き伸ばすと角張るため、カードの大きさで作り直す。
    func loadShareCardMapsIfNeeded() async {
        guard shareCardMaps == nil else { return }
        await load(key: "share-card") { repository, manifest in
            let selector = BoundaryLODSelector(transitions: manifest.lodTransitions)
            let lod = selector.coarsestLOD
            // 横360ptの日本地図で約1.5pt(約7km)未満の島は描かないので、デコード直後に捨ててメモリを抑える。
            let pieceFilter = BoundaryPieceFilter(visibleWidthMeters: 700_000)
            let prefectures = try await repository.boundaries(
                in: manifest.files(in: .prefectures, lod: lod, intersecting: Self.wholeWorld), pieceFilter: pieceFilter
            )
            let municipalities = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: lod, intersecting: Self.wholeWorld), pieceFilter: pieceFilter
            )
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.shareCardMapResolution, projectionKind: .mercator)
            let okinawaMainIsland = prefectures
                .first { $0.code == BoundarySilhouetteBuilder.japanInsetPrefectureCode }?
                .polygons.first?.boundingBox
            // 全国の市区町村で数万頂点を間引くので、メインスレッドの外で行う。
            let maps = await Task.detached(priority: .userInitiated) {
                ShareCardMaps(
                    prefectureMap: builder.japanMap(of: prefectures),
                    municipalityMap: builder.japanMunicipalityMap(of: municipalities, okinawaMainIsland: okinawaMainIsland)
                )
            }.value
            try Task.checkCancellation()
            self.shareCardMaps = maps
        }
    }

    /// シェア用のカードに大きく描く都道府県の地図を用意する。読み込み済み・読み込み中なら何もしない。
    ///
    /// 進捗の隣の地図(96pt基準・LOD1)を引き伸ばすと角張るため、カードの大きさ(360pt基準)で作り直す。
    /// 最も小さい県(約100km)を横360ptに描くと1pt≒300mなので、150m間引きのLOD2を使う。1県1ファイルで最大でも数MB。
    func loadSharePrefectureMapIfNeeded(code: String) async {
        guard sharePrefectureMaps[code] == nil else { return }
        await load(key: "share-prefecture-\(code)") { repository, manifest in
            // 1km未満の島は描かない(横360ptの最も小さい県でも約3pt。小さな島は`prefectureMap`がさらに省く)。
            let loadFilter = BoundaryPieceFilter(visibleWidthMeters: 100_000)
            let prefecture = try await repository.boundaries(
                in: manifest.files(in: .prefectures, lod: Self.shareRegionLOD, prefectureCode: code),
                pieceFilter: loadFilter
            ).first
            let municipalities = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: Self.shareRegionLOD, prefectureCode: code),
                pieceFilter: loadFilter
            )
            guard let prefecture else {
                self.logger.error("都道府県\(code, privacy: .public)の境界ファイルが見つかりません")
                return
            }
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.shareCardMapResolution, projectionKind: .mercator)
            let map = await Task.detached(priority: .userInitiated) {
                builder.prefectureMap(of: prefecture, municipalities: municipalities)
            }.value
            try Task.checkCancellation()
            self.sharePrefectureMaps[code] = map
        }
    }

    /// シェア用のカードに大きく描く政令指定都市の地図(区ごとに分けたもの)を用意する。読み込み済み・読み込み中なら何もしない。
    ///
    /// 政令指定都市(約20〜50km)を横360ptに描くと1pt≒60〜140mなので、50m間引きのLOD3を使う。
    /// - Parameters:
    ///   - cityCode: 市そのものの行政区域コード。地図の保存のキーに使う。
    ///   - wardCodes: 描く区の行政区域コード。境界データには市の形が無く区の形だけがあるため、区を集めて地図にする。
    func loadShareDesignatedCityMapIfNeeded(cityCode: String, wardCodes: Set<String>) async {
        guard shareDesignatedCityMaps[cityCode] == nil, !wardCodes.isEmpty else { return }
        let prefectureCode = String(cityCode.prefix(2))
        await load(key: "share-city-\(cityCode)") { repository, manifest in
            // 県のファイルごと読むが、この市の区以外はすぐ捨てる。300m未満の岩礁は描かない(横360ptで約2〜5pt)。
            let wards = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: Self.shareDesignatedCityLOD, prefectureCode: prefectureCode),
                pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 30_000)
            ).filter { wardCodes.contains($0.code) }
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.shareCardMapResolution, projectionKind: .mercator)
            let map = await Task.detached(priority: .userInitiated) { builder.designatedCityMap(of: wards) }.value
            try Task.checkCancellation()
            guard let map else {
                self.logger.error("政令指定都市\(cityCode, privacy: .public)の区の境界が見つかりません")
                return
            }
            self.shareDesignatedCityMaps[cityCode] = map
        }
    }

    /// シェア用のカード(豆知識・初訪問)に描く市区町村単体の地図を用意する。読み込み済み・読み込み中なら何もしない。
    ///
    /// 詳細画面の形(`municipalityMaps`)と同じ最も細かいLODから作るが、本物の地図に重ねるためメルカトル図法で作り直す。
    func loadShareMunicipalityMapIfNeeded(code: String) async {
        guard shareMunicipalityMaps[code] == nil else { return }
        let prefectureCode = String(code.prefix(2))
        await load(key: "share-municipality-\(code)") { repository, manifest in
            guard let lod = manifest.lods.map(\.id).max() else { return }
            let municipality = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: lod, prefectureCode: prefectureCode),
                pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 5_000)
            ).first { $0.code == code }
            guard let municipality else {
                self.logger.error("市区町村\(code, privacy: .public)の境界が見つかりません")
                return
            }
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.shareCardMapResolution, projectionKind: .mercator)
            let map = await Task.detached(priority: .userInitiated) { builder.municipalityMap(of: municipality) }.value
            try Task.checkCancellation()
            self.shareMunicipalityMaps[code] = map
        }
    }

    /// シェア用の都道府県の地図に使うLOD(150m間引き)。
    private static let shareRegionLOD = 2
    /// シェア用の政令指定都市の地図に使うLOD(50m間引き)。
    private static let shareDesignatedCityLOD = 3

    /// 都道府県の地図を用意する。読み込み済み・読み込み中なら何もしない。
    func loadPrefectureMapIfNeeded(code: String) async {
        guard prefectureMaps[code] == nil else { return }
        await load(key: "prefecture-\(code)") { repository, manifest in
            // 最も小さい県(香川県・大阪府、約100km)の枠でも1pt≒1kmなので、1km未満の島は描かない。
            let loadFilter = BoundaryPieceFilter(visibleWidthMeters: 100_000)
            let prefecture = try await repository.boundaries(
                in: manifest.files(in: .prefectures, lod: Self.prefectureLOD, prefectureCode: code),
                pieceFilter: loadFilter
            ).first
            let municipalities = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: Self.prefectureLOD, prefectureCode: code),
                pieceFilter: loadFilter
            )
            guard let prefecture else {
                self.logger.error("都道府県\(code, privacy: .public)の境界ファイルが見つかりません")
                return
            }
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.areaMapResolution)
            let map = await Task.detached(priority: .utility) {
                builder.prefectureMap(of: prefecture, municipalities: municipalities)
            }.value
            try Task.checkCancellation()
            self.prefectureMaps[code] = map
        }
    }

    /// 市区町村単体の地図を用意する。読み込み済み・読み込み中なら何もしない。
    func loadMunicipalityMapIfNeeded(code: String) async {
        guard municipalityMaps[code] == nil else { return }
        // 行政区域コードの先頭2桁は都道府県コード。
        let prefectureCode = String(code.prefix(2))
        await load(key: "municipality-\(code)") { repository, manifest in
            // 5km四方ほどの区を画面幅で描くと1pt≒15mになるため、最も細かいLOD(20m)を使う。
            // 1県1ファイルで最大約3.5MB。詳細画面を開いたときだけ読む。
            guard let lod = manifest.lods.map(\.id).max() else { return }
            // 県のファイルごと読むが、この市区町村以外はすぐ捨てる。50m未満の岩礁は描かない。
            let municipality = try await repository.boundaries(
                in: manifest.files(in: .municipalities, lod: lod, prefectureCode: prefectureCode),
                pieceFilter: BoundaryPieceFilter(visibleWidthMeters: 5_000)
            ).first { $0.code == code }
            guard let municipality else {
                self.logger.error("市区町村\(code, privacy: .public)の境界が見つかりません")
                return
            }
            let builder = BoundarySilhouetteBuilder(targetPoints: Self.municipalityMapResolution)
            let map = await Task.detached(priority: .utility) { builder.municipalityMap(of: municipality) }.value
            try Task.checkCancellation()
            self.municipalityMaps[code] = map
        }
    }

    /// 読み込みの共通部分。同じ`key`の読み込みが進行中なら何もしない。
    ///
    /// 地図の`MunicipalityPuzzleStore`とはリポジトリを共有しない。リポジトリのキャッシュはファイル単位で
    /// 「同じファイルには同じフィルタ」が前提のため。作った地図だけを残し、デコード結果は使い終わったら捨てる。
    private func load(
        key: String,
        _ operation: (BoundaryRepository, BoundaryManifest) async throws -> Void
    ) async {
        guard !loadingKeys.contains(key) else { return }
        loadingKeys.insert(key)
        defer { loadingKeys.remove(key) }

        do {
            let repository = BoundaryRepository.bundled()
            let manifest = try await repository.loadManifest()
            try await operation(repository, manifest)
        } catch is CancellationError {
            // 画面を離れただけ。次に表示されたときに読み直す。
        } catch {
            // 小さな地図は進捗の飾りで、無くても踏破率は読める。ユーザーには出さず開発者向けに残す。
            logger.error("地図のシルエットを用意できませんでした(\(key, privacy: .public)): \(String(describing: error), privacy: .public)")
        }
    }

    private static let wholeWorld = GeoBoundingBox(minLongitude: -180, minLatitude: -90, maxLongitude: 180, maxLatitude: 90)
}

/// シェア用のカードに描く2種類の日本地図。同じ枠・同じ縮尺で作るので、塗りを切り替えても地図の位置は動かない。
nonisolated struct ShareCardMaps: Sendable {
    /// 区画=都道府県(コード2桁)。
    let prefectureMap: SilhouetteMap
    /// 区画=市区町村(行政区域コード5桁。政令指定都市は区)。
    let municipalityMap: SilhouetteMap
}
