import Foundation

/// 何が「初めて」になったときに知らせるか。ユーザーが「設定」画面で選ぶ。
/// `UserDefaults`に保存するためString型のrawValueを持つ。rawValueを変えると保存済みの選択が失われるので変えないこと。
enum NewMunicipalityAlertMode: String, CaseIterable, Identifiable {
    case off
    /// 記録が一度もない市区町村に入ったら知らせる。
    case municipality
    /// 記録が一度もない都道府県に入ったときだけ知らせる。県内の市区町村が変わっても知らせない。
    case prefecture

    var id: Self { self }

    var title: String {
        switch self {
        case .off: "オフ"
        case .municipality: "市区町村ごと"
        case .prefecture: "都道府県のみ"
        }
    }
}

/// 通知の文言。地図画面の誘いシートと同じく「初訪問」と呼ぶ。
/// タイトルで区域を、本文でその土地のみどころ(なければ怪奇・都市伝説)の冒頭を見せ、開いて続きを読みたくなるようにする。
enum NewMunicipalityAlertMessage {
    struct Content: Equatable {
        let title: String
        /// 空なら付けない。
        let subtitle: String
        let body: String
    }

    /// 本文に載せる豆知識の長さの上限(文字)。ロック画面・バナーで切れずに読める3行ほどに収める。
    static let excerptLimit = 60

    /// - Parameters:
    ///   - areaName: 市区町村なら都道府県名から続けた名前(「東京都中央区」)、都道府県なら県名(「埼玉県」)。
    ///   - triviaExcerpt: 本文に載せる豆知識の冒頭(`triviaExcerpt(famousThingsTrivia:historyTrivia:placeName:)`)。
    ///     無ければ記録を誘う一文にする。
    ///   - recordedName: 有料機能「自動で記録」で記録した市区町村の、都道府県名から続けた名前。記録しなかった場合はnil。
    ///     都道府県モードでは区域と異なるため書き添える。
    static func content(areaName: String, triviaExcerpt: String?, recordedName: String?) -> Content {
        let title = "\(areaName)に初訪問"
        let recordedNote = recordedName.map { $0 == areaName ? "よりみちに記録しました" : "\($0)をよりみちに記録しました" }
        guard let triviaExcerpt else {
            return Content(title: title, subtitle: "", body: recordedNote.map { "\($0)。" } ?? "よりみちを開いて記録しませんか？")
        }
        return Content(title: title, subtitle: recordedNote ?? "", body: triviaExcerpt)
    }

    /// みどころの最初の一文(無ければ怪奇・都市伝説の最初の一文)。長ければ`excerptLimit`で切って「…」を付ける。
    /// どちらも空(マスタに豆知識が無い市区町村)ならnil。
    /// - Parameter placeName: 豆知識の市区町村が通知の区域と違う(都道府県モード)ときに頭に添える名前。
    static func triviaExcerpt(famousThingsTrivia: String, historyTrivia: String, placeName: String?) -> String? {
        let trivia = [famousThingsTrivia, historyTrivia]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let trivia else { return nil }
        let sentence = trivia.firstIndex(where: { "。！？".contains($0) }).map { String(trivia[...$0]) } ?? trivia
        let excerpt = sentence.count > excerptLimit ? String(sentence.prefix(excerptLimit - 1)) + "…" : sentence
        return placeName.map { "\($0)：\(excerpt)" } ?? excerpt
    }
}

/// 位置情報を「常に」許可してもらう前に添える説明。許可を迷う理由になりやすい電池と、位置の行き先に答える。
/// 住所の確認(`AddressResolver`)ではAppleの地図サービスに座標を渡すため、「iPhoneの中で完結」とは書かない。
/// 開発者のサーバーは無く、SwiftDataはCloudKitで同期していないので、下の2文は実装と一致している。
/// 通信先やデータの保存先を変えるときは、この文言も見直すこと。
enum LocationUsageAssurance {
    static let battery = "GPSを動かし続けず、大まかな位置の変化だけを受け取るので、電池への負担はわずかです。"
    static let privacy = "位置情報は開発者に送りません。記録はこのiPhoneの中だけに保存します。"
}

/// 「記録が一度もない場所に入った」通知の判定に使う、これまでの判定の履歴。モードごとに別々に持つ。
/// アプリは位置の変化で裏で起こされては終了されるため、UserDefaultsに保存して起動をまたいで引き継ぐ。
struct NewMunicipalityAlertHistory: Codable, Equatable {
    /// 最後に判定した区域(市区町村または都道府県)のコード。同じ区域の中で位置が変わっただけでは通知しないために使う。
    var lastAreaCode: String?
    /// 知らせた区域のコードと日時。境界付近で行き来したときに同じ区域を何度も通知しないために使う。
    /// アプリが前面にあって地図画面の誘いシートに任せた場合も「知らせた」に含める。
    /// `NewMunicipalityAlertPolicy.renotifyInterval`より古いものは判定のたびに捨てる。
    var notifiedAt: [String: Date] = [:]

    // 市区町村だけを判定していた版で保存した履歴をそのまま読めるよう、保存時のキー名を保つ。
    private enum CodingKeys: String, CodingKey {
        case lastAreaCode = "lastMunicipalityCode"
        case notifiedAt
    }
}

/// 判定した区域について通知するかどうかを決める。位置情報・通知・SwiftDataには依存しない。
/// 市区町村と都道府県のどちらのモードでも、区域のコードと記録済みのコードを渡せば同じ規則で判定する。
///
/// 「初めて」の判定は既存の記録をそのまま使う(どの記録を記録済みとみなすかは呼び出し側が決める)。
struct NewMunicipalityAlertPolicy {
    /// 一度通知した区域を、出入りしても再び通知しない期間。
    /// 境界沿いの道を走ると数分おきに出入りするため、少なくともその日のうちは繰り返さない長さにしてある。
    /// 仮の値。実機で使って調整する。
    static let renotifyInterval: TimeInterval = 12 * 60 * 60

    struct Decision: Equatable {
        let shouldNotify: Bool
        /// 判定後に保存し直す履歴。通知しなかった場合も「最後に判定した区域」は進める。
        let updatedHistory: NewMunicipalityAlertHistory
    }

    /// - Parameters:
    ///   - areaCode: 現在地の区域(市区町村または都道府県)のコード。
    ///   - recordedCodes: 記録済みの区域のコード。
    ///   - canPresentNotification: 通知を出してよい状況か。アプリが前面にある間は地図画面が自前の誘いシートを
    ///     出すためfalseにする。falseでも知らせたものとして履歴に残し、裏へ回った後に同じ区域を改めて通知しないようにする。
    func decide(
        areaCode: String,
        recordedCodes: Set<String>,
        history: NewMunicipalityAlertHistory,
        canPresentNotification: Bool,
        now: Date
    ) -> Decision {
        var updatedHistory = history
        updatedHistory.notifiedAt = history.notifiedAt.filter { _, notifiedAt in
            now.timeIntervalSince(notifiedAt) < Self.renotifyInterval
        }
        updatedHistory.lastAreaCode = areaCode

        let hasEnteredAnotherArea = areaCode != history.lastAreaCode
        let isRecorded = recordedCodes.contains(areaCode)
        let wasNotifiedRecently = updatedHistory.notifiedAt[areaCode] != nil
        let shouldInform = hasEnteredAnotherArea && !isRecorded && !wasNotifiedRecently

        if shouldInform {
            updatedHistory.notifiedAt[areaCode] = now
        }
        return Decision(shouldNotify: shouldInform && canPresentNotification, updatedHistory: updatedHistory)
    }
}
