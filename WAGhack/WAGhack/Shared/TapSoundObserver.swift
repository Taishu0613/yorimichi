import MapKit
import SwiftUI
import UIKit

/// アプリ全体のタップで効果音を鳴らす。画面のルートに`.background`で1つだけ置く。
///
/// ボタンごとに鳴らすと呼び出しが画面中に散らばり、新しいボタンで忘れやすい。SwiftUIにはボタンの押下を
/// まとめて受ける仕組みが無いので、UIWindowに受け身のタップ認識を付ける。シートも同じウィンドウに載るので一緒に拾える。
/// `cancelsTouchesInView = false`なので、タッチは今までどおり各ビューへ届く。
///
/// 地図の上のタップは除く。地図は触って動かす場所で、ピンの選択だけ`MapSoundFeedback`が鳴らす。
struct TapSoundObserver: UIViewRepresentable {
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.isUserInteractionEnabled = false
        view.onMoveToWindow = { [coordinator = context.coordinator] window in
            coordinator.attach(to: window)
        }
        return view
    }

    func updateUIView(_ uiView: WindowObservingView, context: Context) {
        context.coordinator.onTap = onTap
    }

    final class WindowObservingView: UIView {
        var onMoveToWindow: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onMoveToWindow?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: () -> Void = {}

        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func attach(to window: UIWindow?) {
            recognizer.view?.removeGestureRecognizer(recognizer)
            window?.addGestureRecognizer(recognizer)
        }

        @objc private func handleTap() {
            onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is MKMapView {
                    return false
                }
                view = current.superview
            }
            return true
        }
    }
}
