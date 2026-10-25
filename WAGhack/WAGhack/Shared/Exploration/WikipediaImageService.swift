import Foundation
import os

/// 都道府県・市区町村の代表画像を日本語版Wikipedia(とWikimedia Commons)から探す、ベストエフォートのサービス。
///
/// 記事名の解決もフィルタリングも簡易なヒューリスティックであり、完全ではない(見出し語の曖昧さ
/// までは解決しきれないケースがある)。失敗しても例外を投げず空配列・nilを返すことで、呼び出し側は
/// 「0枚だった場合」だけを考えればよいようにしている。失敗理由はログに残す(握りつぶさない)。
///
/// - `images`・`curatedImage`: 初訪問の演出などの小さな帯に使う、URLだけの取得(従来どおり)。
/// - `heroPhoto`・`spotPhoto`: 市区町村の詳細画面に使う、クレジット付きの1枚の取得。候補の選び方は
///   `WikimediaPhotoRanking`(メタデータだけを見る単純な規則)。問い合わせの回数は1枚あたり数回までに抑える。
actor WikipediaImageService {
    static let shared = WikipediaImageService()

    private var cache: [String: [URL]] = [:]
    /// 詳細画面の写真の結果。見つからなかった(nil)ことも覚えて、同じ市区町村・スポットを開き直しても問い合わせ直さない。
    /// 通信失敗・キャンセルは覚えない(次に開いたときに取り直す)。
    private var photoCache: [String: WikimediaPhoto?] = [:]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WAGhack", category: "WikipediaImage")
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        // 演出を待たせたくないので、応答が途絶えたら早めに諦めて「0枚」にフォールバックする。
        config.timeoutIntervalForRequest = 10
        // Wikimediaは識別できるUser-Agentを要求しており、空だと403を返す。標準のCFNetwork表記でも
        // 通るが、ポリシーに沿ってアプリ名を明示しておく。
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let bundleID = Bundle.main.bundleIdentifier ?? "WAGhack"
        config.httpAdditionalHeaders = ["User-Agent": "Yorimichi/\(version) (\(bundleID); iOS)"]
        session = URLSession(configuration: config)
    }

    /// ファイル名を直接指定して1枚だけ取得する。検索結果任せだと狙った絵にならない
    /// (季節違いの富士山、鳥居が写っていない伏見稲荷など)場面向け。日本儀式のように
    /// 表示が1箇所しかなく、厳選した1枚を確実に出したいケースで使う。
    func curatedImage(fileTitle: String) async -> URL? {
        let cacheKey = "file:\(fileTitle)"
        if let cached = cache[cacheKey]?.first { return cached }
        do {
            let data = try await requestAPI(queryItems: [
                URLQueryItem(name: "titles", value: "File:\(fileTitle)"),
                URLQueryItem(name: "prop", value: "imageinfo"),
                URLQueryItem(name: "iiprop", value: "url"),
                // 帯の1枠は約104×92pt(3倍で約312×276px)。横長写真を高さに合わせて切り抜いても500pxで足りる。
                // 800pxではデコードが重く表示時にコマ落ちするため、都道府県・市区町村の画像と同じ幅に揃える
                // (Wikimediaは決まった幅のサムネイルをキャッシュしているので、既存の値に合わせておく)。
                URLQueryItem(name: "iiurlwidth", value: "500"),
            ])
            let response = try JSONDecoder().decode(ImagesResponse.self, from: data)
            guard let urlString = response.query?.pages?.first?.imageinfo?.first?.thumburl,
                  let url = URL(string: urlString)
            else {
                logger.info("curatedImage 見つからない: \(fileTitle, privacy: .public)")
                return nil
            }
            cache[cacheKey] = [url]
            return url
        } catch {
            logger.error("curatedImage \(fileTitle, privacy: .public): 失敗 \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// `municipalityName`を渡すと市区町村の画像、nilなら都道府県自体の画像を探す。
    func images(prefectureName: String, municipalityName: String? = nil) async -> [URL] {
        let cacheKey = municipalityName.map { "\(prefectureName)|\($0)" } ?? prefectureName
        if let cached = cache[cacheKey] { return cached }
        do {
            let urls = try await fetchImages(prefectureName: prefectureName, municipalityName: municipalityName)
            // 成功した結果だけキャッシュする。キャンセル(シートを早く閉じた等)や一時的な通信失敗を
            // 空配列としてキャッシュすると、その市区町村は再起動まで二度と画像が出なくなってしまう。
            cache[cacheKey] = urls
            logger.info("\(cacheKey, privacy: .public): \(urls.count)枚")
            return urls
        } catch is CancellationError {
            logger.info("\(cacheKey, privacy: .public): キャンセル")
            return []
        } catch {
            logger.error("\(cacheKey, privacy: .public): 失敗 \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// 市区町村の詳細画面の主役に使う、街並み・景色・空撮・名所の横長の写真を1枚探す。見つからなければnil。
    ///
    /// 1. 市区町村の記事の代表画像(pageimages)と、記事内の写真を候補にする。記事の写真は編集者が選んだものなので
    ///    当たりやすく、1回の問い合わせでまとめてメタデータまで取れる。
    /// 2. その中に景色を示す写真が無ければ、記事に対応するCommonsのカテゴリ(Wikidataの`P373`)を、
    ///    景色を示す語で1回だけ検索して候補を足す。
    func heroPhoto(prefectureName: String, municipalityName: String) async -> WikimediaPhoto? {
        let cacheKey = "hero:\(prefectureName)|\(municipalityName)"
        if let cached = photoCache[cacheKey] { return cached }
        do {
            let photo = try await fetchHeroPhoto(prefectureName: prefectureName, municipalityName: municipalityName)
            photoCache[cacheKey] = photo
            logger.info("\(cacheKey, privacy: .public): \(photo?.fileTitle ?? "なし", privacy: .public)")
            return photo
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("\(cacheKey, privacy: .public): 失敗 \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// スポットそのものが写った写真を1枚探す。スポットの記事の代表画像を第一にし、記事が無ければCommonsで
    /// スポット名を検索して、説明などにスポット名が現れる写真だけを使う。別の場所の写真を流用しないよう、見つからなければnil。
    func spotPhoto(spotName: String, municipalityName: String) async -> WikimediaPhoto? {
        let cacheKey = "spot:\(municipalityName)|\(spotName)"
        if let cached = photoCache[cacheKey] { return cached }
        do {
            let photo = try await fetchSpotPhoto(spotName: spotName, municipalityName: municipalityName)
            photoCache[cacheKey] = photo
            logger.info("\(cacheKey, privacy: .public): \(photo?.fileTitle ?? "なし", privacy: .public)")
            return photo
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("\(cacheKey, privacy: .public): 失敗 \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func fetchImages(prefectureName: String, municipalityName: String?) async throws -> [URL] {
        let title: String?
        if let municipalityName {
            title = try await resolveMunicipalityTitle(prefectureName: prefectureName, municipalityName: municipalityName)
        } else {
            title = try await searchTopTitle(query: prefectureName)
        }
        guard let title else {
            logger.info("記事が見つからない: \(prefectureName, privacy: .public) \(municipalityName ?? "", privacy: .public)")
            return []
        }
        logger.debug("記事名を解決: \(title, privacy: .public)")
        return try await fetchArticleImages(title: title)
    }

    /// 「都道府県名+市区町村名」で検索すると同名市区町村(例:府中市)を正しく区別できる一方、
    /// 小さな町村では逆に都道府県自体の記事に負けることがある(記事の情報量で負けるため)。
    /// そこで「結果のタイトルに市区町村名そのものが含まれているか」だけを検証し、含まれて
    /// いなければ市区町村名単独の検索に取り直す。
    private func resolveMunicipalityTitle(prefectureName: String, municipalityName: String) async throws -> String? {
        if let combined = try await searchTopTitle(query: prefectureName + municipalityName),
           combined.contains(municipalityName) {
            return combined
        }
        return try await searchTopTitle(query: municipalityName)
    }

    private func searchTopTitle(query: String) async throws -> String? {
        let data = try await requestAPI(queryItems: [
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srlimit", value: "1"),
        ])
        return try JSONDecoder().decode(SearchResponse.self, from: data).query.search.first?.title
    }

    /// 記事内で使われている画像を取得し、実写真らしいものだけに絞る。ロゴ・旗・紋章・地図・
    /// アイコン類はほぼ全てSVGで配信されているため、拡張子をjpg/jpegに限定するだけで
    /// 驚くほどよく除外できる(実際のWikipedia記事で検証済み)。
    private func fetchArticleImages(title: String) async throws -> [URL] {
        let data = try await requestAPI(queryItems: [
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "generator", value: "images"),
            URLQueryItem(name: "gimlimit", value: "40"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url"),
            URLQueryItem(name: "iiurlwidth", value: "500"),
        ])
        let response = try JSONDecoder().decode(ImagesResponse.self, from: data)
        let photoExtensions = [".jpg", ".jpeg"]
        let urls = (response.query?.pages ?? [])
            .filter { page in photoExtensions.contains { page.title.lowercased().hasSuffix($0) } }
            .compactMap { $0.imageinfo?.first?.thumburl }
            .compactMap(URL.init(string:))
        return Array(urls.prefix(3))
    }

    // MARK: - 詳細画面の写真

    private func fetchHeroPhoto(prefectureName: String, municipalityName: String) async throws -> WikimediaPhoto? {
        guard let title = try await resolveMunicipalityTitle(prefectureName: prefectureName, municipalityName: municipalityName)
        else { return nil }
        let article = try await fetchArticleSummary(title: title)
        var candidates = try await fetchArticlePhotoCandidates(title: title, leadFileTitle: article.leadFileTitle)
        if WikimediaPhotoRanking.rankedHeroes(candidates).first.map({ $0.score < WikimediaPhotoRanking.satisfyingHeroScore }) ?? true,
           let itemID = article.wikidataItemID,
           let category = try await fetchCommonsCategory(itemID: itemID) {
            candidates += try await searchCommonsSceneryCandidates(category: category)
        }
        return WikimediaPhotoRanking.rankedHeroes(candidates).first?.photo
    }

    private func fetchSpotPhoto(spotName: String, municipalityName: String) async throws -> WikimediaPhoto? {
        let spotCore = SpotNameNormalizer.core(of: spotName)
        guard !spotCore.isEmpty else { return nil }
        // 1. スポットの記事。検索結果の題名がスポット名と一致(どちらかがもう一方を含む)するものだけを使う。
        let data = try await requestAPI(queryItems: [
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(spotName) \(municipalityName)"),
            URLQueryItem(name: "gsrlimit", value: "3"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "piprop", value: "name"),
        ])
        let pages = try JSONDecoder().decode(PageImagesResponse.self, from: data).query?.pages ?? []
        let matchingArticle = pages
            .sorted { ($0.index ?? .max) < ($1.index ?? .max) }
            .first { page in
                let titleCore = SpotNameNormalizer.core(of: page.title)
                return page.pageimage != nil && (titleCore.contains(spotCore) || spotCore.contains(titleCore))
            }
        if let leadFile = matchingArticle?.pageimage {
            let data = try await requestAPI(queryItems: [
                URLQueryItem(name: "titles", value: "File:\(leadFile)"),
            ] + Self.imageInfoQuery(thumbnailWidth: Self.thumbnailWidth))
            let candidates = try photoCandidates(from: data, leadFileTitle: leadFile)
            if let photo = candidates.first(where: { WikimediaPhotoRanking.isUsableSpotPhoto($0, spotName: spotName) })?.photo {
                return photo
            }
        }
        // 2. Commonsでスポット名をそのまま検索する。説明などにスポット名が無い写真は採らない。
        let searchData = try await requestAPI(host: .commons, queryItems: [
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrsearch", value: "\"\(spotName)\" filetype:bitmap"),
            URLQueryItem(name: "gsrlimit", value: "8"),
        ] + Self.imageInfoQuery(thumbnailWidth: Self.thumbnailWidth))
        return try photoCandidates(from: searchData, leadFileTitle: nil)
            .first { WikimediaPhotoRanking.isUsableSpotPhoto($0, spotName: spotName) }?
            .photo
    }

    private struct ArticleSummary {
        let leadFileTitle: String?
        let wikidataItemID: String?
    }

    private func fetchArticleSummary(title: String) async throws -> ArticleSummary {
        let data = try await requestAPI(queryItems: [
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "prop", value: "pageimages|pageprops"),
            URLQueryItem(name: "piprop", value: "name"),
            URLQueryItem(name: "ppprop", value: "wikibase_item"),
        ])
        let page = try JSONDecoder().decode(PageImagesResponse.self, from: data).query?.pages?.first
        return ArticleSummary(leadFileTitle: page?.pageimage, wikidataItemID: page?.pageprops?.wikibaseItem)
    }

    /// 記事内の写真を、メタデータ付きで1回の問い合わせでまとめて取る。並びは記事内の順ではなく
    /// ファイル名順で返ってくるため、従来の「先頭の数枚」ではなく`WikimediaPhotoRanking`で選び直す。
    private func fetchArticlePhotoCandidates(title: String, leadFileTitle: String?) async throws -> [WikimediaPhotoCandidate] {
        let data = try await requestAPI(queryItems: [
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "generator", value: "images"),
            URLQueryItem(name: "gimlimit", value: "50"),
        ] + Self.imageInfoQuery(thumbnailWidth: Self.heroWidth))
        return try photoCandidates(from: data, leadFileTitle: leadFileTitle)
    }

    /// 記事に対応するCommonsのカテゴリ名(Wikidataの`P373`)。
    private func fetchCommonsCategory(itemID: String) async throws -> String? {
        let data = try await requestAPI(host: .wikidata, queryItems: [
            URLQueryItem(name: "entity", value: itemID),
            URLQueryItem(name: "property", value: "P373"),
        ])
        return try JSONDecoder().decode(ClaimsResponse.self, from: data).claims?["P373"]?.first?.mainsnak.datavalue?.value
    }

    /// Commonsのカテゴリ(下位カテゴリを含む)の中から、景色を示す語を持つ写真を探す。問い合わせは1回だけにする。
    /// 語はCommonsのファイル名・カテゴリに多い英語を中心に、日本語の説明向けの語を少し足している。
    private func searchCommonsSceneryCandidates(category: String) async throws -> [WikimediaPhotoCandidate] {
        let keywords = ["aerial", "skyline", "cityscape", "panorama", "view", "landscape", "空撮", "風景", "街並み", "夜景"]
        let query = "deepcat:\"\(category)\" filetype:bitmap (\(keywords.joined(separator: " OR ")))"
        let data = try await requestAPI(host: .commons, queryItems: [
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrlimit", value: "20"),
        ] + Self.imageInfoQuery(thumbnailWidth: Self.heroWidth))
        return try photoCandidates(from: data, leadFileTitle: nil)
    }

    /// ヒーロー写真のサムネイル幅(px)。画面幅(最大約440pt)の2倍強。Wikimediaが用意している標準の幅に合わせる。
    private static let heroWidth = 960
    /// スポットのサムネイル幅(px)。72pt四方を3倍で描いても足りる、標準の幅のひとつ。
    private static let thumbnailWidth = 330

    private static func imageInfoQuery(thumbnailWidth: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|size|mime|extmetadata"),
            URLQueryItem(name: "iiurlwidth", value: String(thumbnailWidth)),
            URLQueryItem(name: "iiextmetadatafilter", value: Metadata.allKeys.joined(separator: "|")),
            URLQueryItem(name: "iiextmetadatalanguage", value: "ja"),
        ]
    }

    /// imageinfoの応答を候補にする。利用条件(ライセンス)を確認できないファイルはここで落とす。
    private func photoCandidates(from data: Data, leadFileTitle: String?) throws -> [WikimediaPhotoCandidate] {
        let pages = try JSONDecoder().decode(ImageInfoResponse.self, from: data).query?.pages ?? []
        let leadTitle = leadFileTitle.map(Self.normalizedFileTitle)
        return pages
            .sorted { ($0.index ?? .max) < ($1.index ?? .max) }
            .compactMap { page in
                guard let info = page.imageinfo?.first else { return nil }
                let fileTitle = Self.normalizedFileTitle(page.title)
                guard let photo = Self.photo(fileTitle: fileTitle, info: info) else { return nil }
                let metadata = info.extmetadata ?? [:]
                let text = [
                    fileTitle,
                    WikimediaHTMLText.plainText(metadata[Metadata.imageDescription]?.value),
                    WikimediaHTMLText.plainText(metadata[Metadata.objectName]?.value),
                    metadata[Metadata.categories]?.value,
                ].compactMap(\.self).joined(separator: " ").lowercased()
                return WikimediaPhotoCandidate(
                    photo: photo, mimeType: info.mime, searchableText: text, isArticleLeadImage: fileTitle == leadTitle
                )
            }
    }

    private static func photo(fileTitle: String, info: ImageInfoResponse.Info) -> WikimediaPhoto? {
        let metadata = info.extmetadata ?? [:]
        guard let thumbnail = info.thumburl.flatMap(URL.init(string:)),
              let filePage = info.descriptionurl.flatMap(URL.init(string:)),
              let width = info.width, let height = info.height,
              metadata[Metadata.nonFree]?.value?.lowercased() != "true",
              let licenseName = WikimediaHTMLText.plainText(metadata[Metadata.licenseShortName]?.value)
        else { return nil }
        let licenseURL = metadata[Metadata.licenseURL]?.value.flatMap(URL.init(string:))
        // ライセンスの文書へのリンクが無いものは、パブリックドメイン・CC0のように表示の義務が無いものだけを使う。
        let isPublicDomain = ["public domain", "pd", "cc0", "copyrighted free use"].contains { licenseName.lowercased().hasPrefix($0) }
        guard licenseURL != nil || isPublicDomain else { return nil }
        let attribution = PhotoAttribution(
            author: WikimediaHTMLText.plainText(metadata[Metadata.artist]?.value),
            licenseName: licenseName,
            licenseURL: licenseURL,
            filePageURL: filePage
        )
        return WikimediaPhoto(fileTitle: fileTitle, imageURL: thumbnail, width: width, height: height, attribution: attribution)
    }

    /// 「ファイル:A_b.jpg」「File:A b.jpg」「A_b.jpg」を同じ「A b.jpg」にそろえる。pageimagesはアンダースコア、
    /// generator=imagesは空白で返すため、代表画像かどうかを比べる前にそろえる必要がある。
    private static func normalizedFileTitle(_ title: String) -> String {
        var name = Substring(title)
        if let colon = title.firstIndex(of: ":"), ["File", "ファイル", "画像", "Image"].contains(title[..<colon]) {
            name = title[title.index(after: colon)...]
        }
        return name.replacingOccurrences(of: "_", with: " ")
    }

    private enum Metadata {
        static let imageDescription = "ImageDescription"
        static let objectName = "ObjectName"
        static let categories = "Categories"
        static let licenseShortName = "LicenseShortName"
        static let licenseURL = "LicenseUrl"
        static let artist = "Artist"
        static let nonFree = "NonFree"
        static let allKeys = [imageDescription, objectName, categories, licenseShortName, licenseURL, artist, nonFree]
    }

    private func requestAPI(host: APIHost = .japaneseWikipedia, queryItems: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(string: host.endpoint)!
        components.queryItems = [
            URLQueryItem(name: "action", value: host == .wikidata ? "wbgetclaims" : "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
        ] + queryItems
        let url = components.url!
        // 混雑時(429/503)はRetry-Afterが短いときだけ1回待って取り直し、長ければ諦める。APIの利用ガイドラインに沿い、
        // 指示より早く問い合わせ直したり、何度も粘ったりしない。
        for attempt in 0..<2 {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { return data }
            if (200..<300).contains(http.statusCode) { return data }
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? Self.defaultRetryAfter
            if attempt == 0, [429, 503].contains(http.statusCode), retryAfter <= Self.maximumRetryAfter {
                logger.info("HTTP \(http.statusCode)のため\(retryAfter)秒待って取り直します")
                try await Task.sleep(for: .seconds(retryAfter))
                continue
            }
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        throw URLError(.badServerResponse)
    }

    /// Retry-Afterが無いときに待つ秒数と、待ってもよい上限。画面を開いたまま長く待たせないよう短くする。
    private static let defaultRetryAfter: Double = 1
    private static let maximumRetryAfter: Double = 3

    enum APIHost {
        case japaneseWikipedia
        case commons
        case wikidata

        var endpoint: String {
            switch self {
            case .japaneseWikipedia: "https://ja.wikipedia.org/w/api.php"
            case .commons: "https://commons.wikimedia.org/w/api.php"
            case .wikidata: "https://www.wikidata.org/w/api.php"
            }
        }
    }

    private struct SearchResponse: Decodable {
        struct Query: Decodable { let search: [Result] }
        struct Result: Decodable { let title: String }
        let query: Query
    }

    private struct ImagesResponse: Decodable {
        struct Query: Decodable { let pages: [Page]? }
        struct Page: Decodable {
            let title: String
            let imageinfo: [ImageInfo]?
        }
        struct ImageInfo: Decodable { let thumburl: String? }
        let query: Query?
    }

    private struct PageImagesResponse: Decodable {
        struct Query: Decodable { let pages: [Page]? }
        struct Page: Decodable {
            let title: String
            let index: Int?
            let pageimage: String?
            let pageprops: PageProps?
        }
        struct PageProps: Decodable {
            let wikibaseItem: String?
            enum CodingKeys: String, CodingKey { case wikibaseItem = "wikibase_item" }
        }
        let query: Query?
    }

    private struct ImageInfoResponse: Decodable {
        struct Query: Decodable { let pages: [Page]? }
        struct Page: Decodable {
            let title: String
            let index: Int?
            let imageinfo: [Info]?
        }
        struct Info: Decodable {
            let thumburl: String?
            let descriptionurl: String?
            let width: Int?
            let height: Int?
            let mime: String?
            let extmetadata: [String: MetadataValue]?
        }
        /// extmetadataの値は基本的に文字列だが、項目によっては数値が入るため、文字列以外は無視する。
        struct MetadataValue: Decodable {
            let value: String?
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                value = try? container.decode(String.self, forKey: .value)
            }
            enum CodingKeys: String, CodingKey { case value }
        }
        let query: Query?
    }

    private struct ClaimsResponse: Decodable {
        struct Claim: Decodable { let mainsnak: Snak }
        struct Snak: Decodable { let datavalue: DataValue? }
        struct DataValue: Decodable { let value: String? }
        let claims: [String: [Claim]]?
    }
}
