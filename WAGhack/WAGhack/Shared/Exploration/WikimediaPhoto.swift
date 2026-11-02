import Foundation

/// Wikimedia(Wikipedia/Commons)から取得した写真1枚と、その利用条件。
///
/// 表示に使うのはサムネイルの`imageURL`だけで、ファイルページ・ライセンスはクレジット表示のために持つ。
/// 一覧のおすすめ画像として永続化はしない(表示中の画面とサービスのメモリキャッシュだけで使う)。
nonisolated struct WikimediaPhoto: Identifiable, Hashable, Sendable {
    /// 名前空間(「File:」「ファイル:」)を除いたファイル名。WikipediaとCommonsで同じファイルなら同じ値になる。
    let fileTitle: String
    let imageURL: URL
    /// 原寸の大きさ(px)。縦横比の判定に使う。
    let width: Int
    let height: Int
    let attribution: PhotoAttribution

    var id: String { fileTitle }
}

/// 写真のクレジット。値はすべてWikimediaのextmetadataから取り、HTMLは取り除いてある。
nonisolated struct PhotoAttribution: Hashable, Sendable {
    /// 作者。Commonsで「作者不明」のファイルもあるのでnilになりうる。
    let author: String?
    let licenseName: String
    let licenseURL: URL?
    /// Commons(またはWikipedia)のファイルページ。出典としてここへ案内する。
    let filePageURL: URL
}

/// extmetadataの値はHTML(作者のリンクなど)を含むため、表示用の素の文字列にする。
///
/// `NSAttributedString`のHTML読み込みはメインスレッド専用で重いため使わず、タグを外して代表的な文字参照だけを戻す。
/// 表示はTextに素の文字列として渡すだけなので、ここで残った記号がスクリプトとして解釈されることはない。
nonisolated enum WikimediaHTMLText {
    static func plainText(_ html: String?) -> String? {
        guard let html else { return nil }
        var text = html.replacing(/<[^>]*>/, with: " ")
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&#039;": "'", "&nbsp;": " "]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        text = text.replacing(/&#(\d+);/) { match in
            UInt32(match.output.1).flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? ""
        }
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }
}
