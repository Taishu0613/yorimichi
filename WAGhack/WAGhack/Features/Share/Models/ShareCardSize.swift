import CoreGraphics
import Foundation

/// シェア用カードの形(縦長・正方形)。書き出す画像のピクセル寸法を決める。
///
/// 1.8.0 (7)で、カードの並び方(`ShareCardLayout`: 標準・写真が主役など)と区別するため`ShareCardLayout`から名前を変えた。
enum ShareCardSize: String, CaseIterable, Identifiable, Hashable {
    /// Instagramのストーリーズなどの縦長(9:16)。
    case story
    /// 投稿用の正方形。
    case square

    var id: Self { self }

    var title: String {
        switch self {
        case .story: "縦長(ストーリーズ)"
        case .square: "正方形(投稿)"
        }
    }

    /// 書き出す画像の大きさ(px)。SNSが推奨する1080px幅に合わせる。
    var pixelSize: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .square: CGSize(width: 1080, height: 1080)
        }
    }

    /// カードを組む大きさ(pt)。iPhoneの画面幅に近い横360ptで組み、`renderScale`倍で書き出す。
    /// 文字の大きさを画面で見るときと同じ感覚で決められるようにするため。
    var pointSize: CGSize {
        CGSize(width: pixelSize.width / Self.renderScale, height: pixelSize.height / Self.renderScale)
    }

    static let renderScale: CGFloat = 3
}

/// 地図をどの単位で塗るか。
enum ShareCardFill: String, CaseIterable, Identifiable, Hashable {
    /// 訪れた市区町村を塗る(既定)。
    case municipalities
    /// 訪れた都道府県を塗る。市区町村まで見せたくない人向け。
    case prefectures

    var id: Self { self }

    var title: String {
        switch self {
        case .municipalities: "市区町村まで"
        case .prefectures: "都道府県だけ"
        }
    }
}
