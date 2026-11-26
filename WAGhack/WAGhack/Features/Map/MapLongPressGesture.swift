import SwiftUI
import UIKit

/// 地図の長押しを、押した位置(ビューの座標)付きで受け取るジェスチャー。区域名の吹き出し(`MapScreen.handleMapLongPress`)に使う。
///
/// SwiftUIの`onTapGesture`を`Map`に付けると、タップをSwiftUI側が取ってしまいピン(Marker)を選べなくなった
/// (1.7.2 (14)で発生)。`LongPressGesture`は押した位置を返さないため、UIKitの長押しの認識器を
/// `UIGestureRecognizerRepresentable`で付け、地図自身のジェスチャー(タップでの選択・ドラッグ・ピンチ)と同時に認識させる。
struct MapLongPressGesture: UIGestureRecognizerRepresentable {
    /// 長押しと判定するまでの時間。UIKitの既定(0.5秒)のまま。
    private static let minimumPressDuration: TimeInterval = 0.5

    let action: (CGPoint) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = Self.minimumPressDuration
        // 長押しが成立しても、地図に届いているタッチを取り消さない(ドラッグに移ってもそのまま地図を動かせるように)。
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        // 押したままにしている間も呼ばれ続けるため、長押しが成立した瞬間の1回だけ伝える。
        guard recognizer.state == .began else { return }
        action(context.converter.localLocation)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// 地図自身のジェスチャーを止めないよう、ほかの認識器と常に同時に認識させる。
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
