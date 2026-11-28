import PhotosUI
import SwiftUI
import UIKit

/// シェアに使う写真を写真ライブラリから読み込む。カードの背景にも、ステッカーを貼る写真にも使う。
///
/// カードの大きさ(最大1080×1920px)を覆う大きさまで縮めて、メモリを抑える。
/// 写真の位置情報(Exif)は、カードを描き直した画像には入らない。
enum ShareCardPhotoLoader {
    enum LoadError: Error {
        /// データが画像として読めなかった。
        case unreadableImage
    }

    static func load(_ item: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            throw LoadError.unreadableImage
        }
        let pixelSize = ShareCardSize.story.pixelSize
        let scale = min(1, max(pixelSize.width / image.size.width, pixelSize.height / image.size.height))
        let resizedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return await image.byPreparingThumbnail(ofSize: resizedSize) ?? image
    }
}
