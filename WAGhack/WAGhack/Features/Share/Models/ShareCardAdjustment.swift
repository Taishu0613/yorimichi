import CoreGraphics

/// 写真を敷いたカードで「位置を調整」したときの、箱と形(ポリゴン)のずらし方(1.8.0 (10))。
///
/// (8)の「ステッカーを貼る」を作り変えたもの。レイアウト(`ShareCardBoxSize`)が決めた位置を初めの位置にし、
/// そこからのずれと大きさだけを持つ。何もしなければ`.none`で、レイアウトの位置のまま描く。
/// シェア画面を開いている間だけ持ち、カードの種類・範囲・レイアウトを変えたら`.none`に戻す(調整はそのカードのためのもの)。
nonisolated struct ShareCardAdjustment: Hashable {
    var box = ShareCardElementPlacement()
    var shape = ShareCardElementPlacement()

    static let none = ShareCardAdjustment()

    var isAdjusted: Bool { self != .none }

    subscript(element: ShareCardElement) -> ShareCardElementPlacement {
        get {
            switch element {
            case .box: box
            case .shape: shape
            }
        }
        set {
            switch element {
            case .box: box = newValue
            case .shape: shape = newValue
            }
        }
    }
}

/// 位置を調整するもの。
nonisolated enum ShareCardElement: String, CaseIterable, Identifiable, Hashable {
    case box
    case shape

    var id: Self { self }

    var title: String {
        switch self {
        case .box: "箱"
        case .shape: "形"
        }
    }
}

/// 1つのものの、レイアウトの位置からのずれ(カードの幅・高さに対する割合)と大きさ。
/// 割合で持つのは、縦長・正方形を切り替えても同じあたりに残すため。
nonisolated struct ShareCardElementPlacement: Hashable {
    var unitOffset: CGSize = .zero
    var scale: CGFloat = 1

    static let scaleRange: ClosedRange<CGFloat> = 0.4...2.5
    /// ずらせる幅。カードから全部はみ出して見えなくならないようにする(初めの位置はおおむね真ん中の列にある)。
    static let offsetLimit = CGSize(width: 0.5, height: 0.8)

    func offset(in cardSize: CGSize) -> CGSize {
        CGSize(width: unitOffset.width * cardSize.width, height: unitOffset.height * cardSize.height)
    }

    /// 指で動かした分(カードのpt)だけずらす。
    func moved(by translation: CGSize, in cardSize: CGSize) -> ShareCardElementPlacement {
        var moved = self
        let limit = Self.offsetLimit
        moved.unitOffset = CGSize(
            width: min(max(unitOffset.width + translation.width / cardSize.width, -limit.width), limit.width),
            height: min(max(unitOffset.height + translation.height / cardSize.height, -limit.height), limit.height)
        )
        return moved
    }

    func scaled(by magnification: CGFloat) -> ShareCardElementPlacement {
        var scaled = self
        scaled.scale = min(max(scale * magnification, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        return scaled
    }
}

/// アプリ名「よりみち」を置く角(1.8.0 (10))。いつもカードの右下か右上の角に、端から小さな余白だけあけて置く。
nonisolated enum ShareCardLogoCorner: Hashable {
    case topTrailing
    case bottomTrailing

    /// ふだんは右下。箱(調整した後の位置と大きさ)が右下のアプリ名に重なるときだけ右上にする。
    static func corner(avoiding boxFrame: CGRect?, bottomLogoFrame: CGRect) -> ShareCardLogoCorner {
        guard let boxFrame, boxFrame.intersects(bottomLogoFrame) else { return .bottomTrailing }
        return .topTrailing
    }
}
