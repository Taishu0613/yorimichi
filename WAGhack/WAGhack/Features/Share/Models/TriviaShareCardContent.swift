import Foundation

/// 豆知識のシェア用カードに載せるもの。市区町村の形と名前に、「みどころ」「怪奇・都市伝説」「この街でできること」の
/// どれか1つを添える。「行った自慢」ではなく話のネタとして、旅をしていない人にも届くカードにする。
///
/// 訪問済みかどうかは「訪問済み / まだ行ってない」の印だけで示し、訪問日時や場所は載せない。
struct TriviaShareCardContent: Equatable {
    enum Topic: Hashable {
        /// みどころ(マスタの「豆知識(有名なもの)」)。
        case highlights(String)
        /// 怪奇・都市伝説(マスタの「豆知識(歴史)」)。
        case legend(String)
        /// この街でできること(みどころのマスタの1件)。
        case spot(name: String, line: String)
    }

    let municipalityName: String
    let prefectureName: String
    let isVisited: Bool
    let topic: Topic

    var title: String {
        switch topic {
        case .highlights: "みどころ"
        case .legend: "怪奇・都市伝説"
        case .spot: "この街でできること"
        }
    }

    /// 画像と一緒に共有する文。
    var shareText: String {
        let headline = switch topic {
        case .highlights, .legend: "\(municipalityName)の豆知識 #よりみち"
        case .spot(let name, _): "\(municipalityName)でできること「\(name)」 #よりみち"
        }
        return "\(headline)\n\(ShareCardContent.appStoreURL.absoluteString)"
    }

    /// 都市伝説か。伝説や噂話なので、カードには「※諸説あり」を添える。
    var isLegend: Bool {
        if case .legend = topic { return true }
        return false
    }

    /// まとまりに載せる本文(1.8.0 (8))。写真の上半分を空けるため数行に収める。
    /// みどころ・都市伝説は、`maxLength`字に収まるまで文(「。」まで)を足す(最初の文が長ければ最初の文だけ)。
    /// それでも収まらない分は、描く側が行数で切る。この街でできることは一言そのまま。
    func excerpt(maxLength: Int) -> String {
        switch topic {
        case .highlights(let text), .legend(let text):
            return Self.excerpt(of: text, maxLength: maxLength)
        case .spot(_, let line):
            return line
        }
    }

    static func excerpt(of text: String, maxLength: Int) -> String {
        var result = ""
        for sentence in sentences(of: text) {
            guard result.isEmpty || result.count + sentence.count <= maxLength else { break }
            result += sentence
        }
        return result
    }

    /// 「。」で区切った文(「。」を含む)。最後に「。」の無い文が残れば、それも1文にする。
    static func sentences(of text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var sentences: [String] = []
        var current = ""
        for character in trimmed {
            current.append(character)
            if character == "。" {
                sentences.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { sentences.append(rest) }
        return sentences
    }

    /// 都市伝説の無い街のマスタに入っている決まり文句。これはカードにしても話のネタにならないので、シェアを出さない。
    static let noLegendSuffix = "には、特に有名な怪談・都市伝説はありません。"

    /// 怪奇・都市伝説をシェアできるか。空欄と「特に有名な怪談・都市伝説はありません」はシェアしない。
    static func isShareableLegend(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.hasSuffix(noLegendSuffix)
    }

    /// みどころをシェアできるか。空欄はシェアしない。
    static func isShareableHighlights(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// この街でできることの1件を、カードの話題にする。一言はおすすめの理由、無ければ行動の言葉。
    static func spotTopic(_ spot: YorimichiSpot) -> Topic {
        .spot(name: spot.name, line: spot.reason ?? spot.displayAction ?? "")
    }
}
