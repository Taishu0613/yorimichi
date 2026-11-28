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

/// 写真を敷くレイアウトの地。写真があれば写真、無ければ本物の地図を薄く(撮れるまでは水玉の地)。
struct ShareCardPhotoOrMapBackground: View {
    let photo: UIImage?
    let backdrop: ShareMapBackdrop?
    /// 本物の地図を撮った枠(`ShareCardMapBox.backdropBox`)。
    let box: ShareCardMapBox?
    let size: CGSize

    var body: some View {
        if let photo {
            ShareCardPhotoBackground(photo: photo, size: size)
        } else if let backdrop, let box {
            ShareMapBackdropView(backdrop: backdrop, box: box)
        } else {
            ShareCardBackground()
        }
    }
}

/// カードの縁の余白。縦長はストーリーズの上下に重なるアプリの表示(上約60pt・下約83pt)に文字を掛けない。
/// 正方形の下は、本物の地図の左下に入るAppleマップのロゴ(下端から約8〜22pt)に掛けない。
enum ShareCardInsets {
    static func of(_ size: ShareCardSize) -> EdgeInsets {
        switch size {
        case .story: EdgeInsets(top: 64, leading: 24, bottom: 96, trailing: 24)
        case .square: EdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20)
        }
    }
}

/// 帯や余白の端に添える小さなアプリの印(アイコンと名前)。箱の見た目に合わせて名前の色を変える。
struct ShareCardLogoMark: View {
    var size: CGFloat = 20
    var color: Color = Pop.ink

    var body: some View {
        HStack(spacing: size * 0.25) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            Text("よりみち")
                .font(.system(size: size * 0.55, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .fixedSize()
        }
    }
}
