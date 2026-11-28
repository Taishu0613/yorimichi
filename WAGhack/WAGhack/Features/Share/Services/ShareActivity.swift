import LinkPresentation
import UIKit
import UniformTypeIdentifiers
import os

/// シェアし終えた回数(「旅のおすそわけ」のバッジに使う)。訪問記録とは別に、端末のUserDefaultsに数だけを持つ。
///
/// 数えるのは共有シートで共有・保存を終えたときだけ(`completed == true`)。シートを開いて閉じただけでは数えない。
/// 1.8.0 (6)で足したので、それまでのシェアは数えていない(全員0から始まる)。
nonisolated enum ShareCompletionCounter {
    /// 値は`MapScreen`が`@AppStorage`で読み、変わったらバッジを評価し直す。変えると今までの回数が読めなくなる。
    static let storageKey = "share.completedCount"

    /// 共有シートを閉じたときに呼ぶ。終えたときだけ1つ増やす。
    static func recordShareSheetResult(completed: Bool, in userDefaults: UserDefaults = .standard) {
        guard completed else { return }
        userDefaults.set(userDefaults.integer(forKey: storageKey) + 1, forKey: storageKey)
    }
}

/// シェアのカードを共有シート(`UIActivityViewController`)で開く。
///
/// SwiftUIの`ShareLink`では共有を終えたか(キャンセルしたか)が分からず、シェアの回数を数えられないため、
/// UIKitの共有シートを使う(1.8.0 (6))。画像と一緒に共有する文(ハッシュタグとApp StoreのURL)を渡す。
enum ShareCardActivity {
    private static let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "ShareActivity")

    static func present(_ card: RenderedShareCard) {
        guard let presenter = topViewController() else {
            logger.error("共有シートを出す画面が見つかりませんでした")
            return
        }
        let controller = UIActivityViewController(
            activityItems: [ShareCardImageItemSource(image: card.image, title: card.title, pngFileURL: transparentFileURL(for: card)), card.message],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, error in
            if let error {
                logger.error("共有を終えられませんでした: \(String(describing: error), privacy: .public)")
            }
            ShareCompletionCounter.recordShareSheetResult(completed: completed)
        }
        // iPadでは吹き出しで出すので、画面の下の真ん中(シェアするボタンのあたり)から出す。
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.maxY - 80, width: 1, height: 1)
        }
        presenter.present(controller, animated: true)
    }

    /// 背景が透明なカード(ステッカー)は、PNGのファイルにして渡す。`UIImage`のまま渡すと、
    /// 「画像を保存」でJPEGに変えられて透明なところが黒・白になることがあるため(写真への保存はファイルの中身をそのまま残す)。
    /// 不透明なカードはこれまでどおり`UIImage`で渡す(nil)。ファイルは一時フォルダに置き、次に書くときに上書きする。
    private static func transparentFileURL(for card: RenderedShareCard) -> URL? {
        guard card.isTransparent, let data = card.image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yorimichi-sticker.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            logger.error("ステッカーのPNGを書き出せませんでした: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// いちばん手前の画面(シェア画面のシートの上でも出せるよう、表示中のものをたどる)。
    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// 共有シートに渡す画像。共有シートの上部に、カードの見出しと画像の縮小を出す。
private final class ShareCardImageItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String
    /// 背景が透明なカードのPNGのファイル。あればこちらを渡す(透明を残すため)。
    private let pngFileURL: URL?

    init(image: UIImage, title: String, pngFileURL: URL?) {
        self.image = image
        self.title = title
        self.pngFileURL = pngFileURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        pngFileURL ?? image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        pngFileURL ?? image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        pngFileURL != nil ? UTType.png.identifier : UTType.image.identifier
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
