import SwiftUI
import UIKit

/// どのカードでも使う地・写真・アプリの印。

/// カードの地。薄いテーマ色に、水玉を散らしてPOPに見せる。
struct ShareCardBackground: View {
    var body: some View {
        Pop.themeSoft
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 22
                    var row = 0
                    var y: CGFloat = 0
                    while y < size.height + spacing {
                        var x: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                        while x < size.width + spacing {
                            context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(.white.opacity(0.8)))
                            x += spacing
                        }
                        y += spacing * 0.87
                        row += 1
                    }
                }
            }
    }
}

/// 右下に添えるアプリの印。
struct ShareCardAppMark: View {
    let logoSize: CGFloat
    /// 写真の上に置くとき。どんな色の写真でも読めるよう、白い札に載せる。
    var isOverPhoto = false

    var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)
                Text("よりみち")
                    .font(.system(size: logoSize * 0.55, weight: .black, design: .rounded))
                    .foregroundStyle(Pop.ink)
            }
            .padding(.vertical, isOverPhoto ? logoSize * 0.15 : 0)
            .padding(.leading, isOverPhoto ? logoSize * 0.2 : 0)
            .padding(.trailing, isOverPhoto ? logoSize * 0.4 : 0)
            .background {
                if isOverPhoto {
                    Capsule().fill(Color.white.opacity(0.88))
                }
            }
        }
    }
}

/// 写真をカードいっぱいに敷く。初訪問・豆知識のカードで共通。
struct ShareCardPhotoBackground: View {
    let photo: UIImage
    let size: CGSize

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

/// ステッカーを貼った写真の縁の余白。縦長はストーリーズの上下に重なるアプリの表示(上約60pt・下約83pt)に文字を掛けない。
enum ShareCardInsets {
    static func of(_ size: ShareCardSize) -> EdgeInsets {
        switch size {
        case .story: EdgeInsets(top: 64, leading: 24, bottom: 96, trailing: 24)
        case .square: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        }
    }
}
