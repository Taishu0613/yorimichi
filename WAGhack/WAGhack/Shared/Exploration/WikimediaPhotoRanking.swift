import Foundation

/// 写真の候補(ファイル名・説明・カテゴリ・大きさ・ライセンス)だけを見て、使えるかと優先順位を決める規則。
///
/// 画像の中身は見ない(AIで推測したり美しさを採点したりしない)。メタデータから判断できないものは高く扱わず、
/// 取得順とフォールバック(シルエット・カテゴリのアイコン)で補う。規則はキーワードの有無と縦横比だけの単純なものにして、
/// なぜその写真が選ばれたかをコードから追えるようにしている。
nonisolated struct WikimediaPhotoCandidate: Sendable {
    let photo: WikimediaPhoto
    let mimeType: String?
    /// ファイル名・説明・題名・カテゴリをつなげて小文字にしたもの。キーワードの照合にだけ使う。
    let searchableText: String
    /// Wikipediaの記事の代表画像(pageimages)か。記事の編集者が選んだ1枚なので優先する。
    var isArticleLeadImage = false
}

nonisolated enum WikimediaPhotoRanking {
    /// 街並み・眺望・空撮などを示す語。ヒーロー写真で優先する。英語はCommonsのファイル名・カテゴリ向け。
    static let sceneryKeywords = [
        "空撮", "航空写真", "俯瞰", "遠景", "全景", "街並", "町並", "市街", "景観", "風景", "夜景", "眺望", "眺め", "パノラマ",
        "panorama", "skyline", "cityscape", "aerial", "bird's-eye", "birds-eye", "view", "landscape", "scenery",
        "townscape", "streetscape", "downtown", "overview",
    ]
    /// その街を見に行く理由になりにくい記録写真の語。象徴的な場合もあるので除外はせず、順位を下げるだけにする。
    static let mundaneKeywords = [
        "庁舎", "役所", "役場", "city hall", "town hall", "village office", "office", "病院", "hospital", "学校", "高校",
        "school", "大学", "university", "消防", "fire station", "警察", "police", "看板", "signboard", "標識", "交差点",
        "crossing", "国道", "route", "道路", "銀行", "supermarket", "マンション", "apartment", "停留所", "bus stop",
    ]
    /// 写真ではない(旗・紋章・地図・図表など)か、写真として街の紹介に向かないものを示す語。候補から外す。
    static let excludedKeywords = [
        "flag", "旗", "logo", "ロゴ", "emblem", "紋章", "coat of arms", "seal of", "map", "地図", "位置図", "locator",
        "diagram", "chart", "グラフ", "symbol", "記号", "icon", "浮世絵", "ukiyo-e", "woodblock", "painting", "絵図",
    ]

    /// ヒーロー写真の最低限の大きさ(原寸の幅px)。これより小さいと画面幅に広げたときに粗く見える。
    static let minimumHeroWidth = 800
    /// スポットのサムネイルの最低限の大きさ(原寸の短い辺px)。72pt四方を3倍で描く程度あれば足りる。
    static let minimumThumbnailSide = 240
    /// ヒーロー写真に採用する最低の点数。記事の代表画像(+5)か、景色を示す語(+6)のどちらかが必要になる。
    static let minimumHeroScore = 3
    /// この点数以上の候補があれば、追加の検索(Commons)をしない。景色の語を持つ横長の写真がこれに当たる。
    static let satisfyingHeroScore = 8

    /// ヒーロー写真としての点数。使えない候補はnil。
    static func heroScore(of candidate: WikimediaPhotoCandidate) -> Int? {
        guard isUsable(candidate), candidate.photo.width >= minimumHeroWidth else { return nil }
        let text = candidate.searchableText
        var score = 0
        if containsAny(text, sceneryKeywords) { score += 6 }
        if candidate.isArticleLeadImage { score += 5 }
        if containsAny(text, mundaneKeywords) { score -= 4 }
        // 表示枠は横長なので、縦長の写真は上下が大きく切れる。除外まではせず順位を下げる。
        let aspectRatio = Double(candidate.photo.width) / Double(max(candidate.photo.height, 1))
        if aspectRatio >= 1.3 {
            score += 2
        } else if aspectRatio < 1.0 {
            score -= 2
        }
        return score
    }

    /// 点数の高い順に並べ、採用できるものだけを返す。同点は代表画像→画素数の多い順→ファイル名順にして、結果を毎回同じにする。
    static func rankedHeroes(_ candidates: [WikimediaPhotoCandidate]) -> [(photo: WikimediaPhoto, score: Int)] {
        var seen: Set<String> = []
        return candidates
            .compactMap { candidate -> (WikimediaPhotoCandidate, Int)? in
                guard seen.insert(candidate.photo.fileTitle).inserted, let score = heroScore(of: candidate),
                      score >= minimumHeroScore else { return nil }
                return (candidate, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.isArticleLeadImage != rhs.0.isArticleLeadImage { return lhs.0.isArticleLeadImage }
                let lhsPixels = lhs.0.photo.width * lhs.0.photo.height
                let rhsPixels = rhs.0.photo.width * rhs.0.photo.height
                if lhsPixels != rhsPixels { return lhsPixels > rhsPixels }
                return lhs.0.photo.fileTitle < rhs.0.photo.fileTitle
            }
            .map { (photo: $0.0.photo, score: $0.1) }
    }

    /// スポットの写真として使えるか。スポットの名前がファイルの説明などに現れることを根拠にする
    /// (記事の代表画像は記事そのものがスポットと一致済みなので、名前の照合を省く)。
    static func isUsableSpotPhoto(_ candidate: WikimediaPhotoCandidate, spotName: String) -> Bool {
        guard isUsable(candidate),
              min(candidate.photo.width, candidate.photo.height) >= minimumThumbnailSide else { return false }
        if candidate.isArticleLeadImage { return true }
        let name = SpotNameNormalizer.core(of: spotName)
        return !name.isEmpty && SpotNameNormalizer.normalize(candidate.searchableText).contains(name)
    }

    /// 種類・内容・ライセンスの共通の条件。JPEGに絞るのは、旗・紋章・地図の大半がSVG/PNGで配信されているため。
    private static func isUsable(_ candidate: WikimediaPhotoCandidate) -> Bool {
        candidate.mimeType == "image/jpeg" && !containsAny(candidate.searchableText, excludedKeywords)
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

/// スポット名の照合用の正規化。空白・括弧書き(「(千葉県)」など)を除き、全角英数を半角にそろえる。
nonisolated enum SpotNameNormalizer {
    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping
            .lowercased()
            .replacingOccurrences(of: "ヶ", with: "ケ")
            .filter { !$0.isWhitespace && $0 != "_" && $0 != "・" }
    }

    /// 括弧書きを除いた名前の芯。「千葉神社(千葉市)」→「千葉神社」。
    static func core(of name: String) -> String {
        let withoutParentheses = name.replacing(/[\(（][^\)）]*[\)）]/, with: "")
        return normalize(withoutParentheses)
    }
}
