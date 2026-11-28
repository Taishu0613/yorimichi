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
