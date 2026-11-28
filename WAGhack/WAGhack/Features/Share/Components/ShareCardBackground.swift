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

/// 写真を敷いたカードで、形と箱を並べる範囲の余白(1.8.0 (10))。
/// 縦長はストーリーズの上下に重なるアプリの表示(上約60pt・下約83pt)に箱の文字を掛けない。
/// 下は右下の角のアプリ名(`ShareCardAppMark.cornerFrame`)と箱が重ならない広さを空ける。
enum ShareCardInsets {
    static func photoContent(_ size: ShareCardSize) -> EdgeInsets {
        switch size {
        case .story: EdgeInsets(top: 52, leading: 18, bottom: 96, trailing: 18)
        case .square: EdgeInsets(top: 14, leading: 16, bottom: 44, trailing: 16)
        }
    }
}

extension ShareCardAppMark {
    /// 角に置くアプリ名の大きさ。1.8.0 (10)で「もっと端でいい」との声から、箱の下の行をやめて角に小さめに置く。
    static func logoSize(for size: ShareCardSize) -> CGFloat {
        switch size {
        case .story: 24
        case .square: 20
        }
    }

    /// カードの端からアプリ名までの余白。
    static func margin(for size: ShareCardSize) -> CGFloat {
        switch size {
        case .story: 12
        case .square: 10
        }
    }

    /// 写真の上に置いたアプリ名(白い札)のおおよその枠。右下か右上の角に置いた位置で返す。
    /// 箱と重なるかを決めるだけなので、字の幅は1文字あたりロゴの約0.6倍とみて少し広めに取る。
    static func cornerFrame(_ corner: ShareCardLogoCorner, size: ShareCardSize) -> CGRect {
        let cardSize = size.pointSize
        let logoSize = logoSize(for: size)
        let margin = margin(for: size)
        let width = logoSize * (1 + 0.2 + 0.4 + 4 * 0.6) + 8
        let height = logoSize * 1.3
        let y = corner == .topTrailing ? margin : cardSize.height - margin - height
        return CGRect(x: cardSize.width - margin - width, y: y, width: width, height: height)
    }
}
