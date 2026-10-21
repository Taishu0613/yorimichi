import Observation
import SwiftUI

/// 初訪問の通知を案内するカードを、1回だけ出すためのゲート。
/// 版番号ではなく「見たかどうか」を保存するので、新規インストールでも、以降の版から使い始めた人でも1回出る。
/// 既にいずれかのモードを選んでいる人(機能を知っている人)には出さない。
///
/// いつ出すかは記録の有無で分ける(`Timing`)。まだ1か所も記録していない人にチュートリアル直後に出すと、
/// アプリの価値を体験する前に通知と位置情報「常に」の許可を求めることになり、最初の記録までの流れも途切れるため。
@MainActor
@Observable
final class NewMunicipalityAlertAnnouncementGate {
    enum Timing {
        /// 既に記録がある人(アップデートで来た人)。機能の追加を、チュートリアルの直後に知らせる。
        case afterTutorial
        /// まだ記録が無い人。初めて市区町村を記録したお祝いを閉じた後に、「次も知らせるか」として誘う。
        case afterFirstRecord
    }

    private static let seenKey = "announcement.newMunicipalityAlert.seen"

    private(set) var isPresented: Bool
    let timing: Timing

    /// 見ていない・まだモードを選んでいない。出す時機を待っている間もtrue。
    private var isPending: Bool
    private let userDefaults: UserDefaults

    /// TutorialGateと同じく初期値をここで同期的に確定させる。初回描画で一瞬でもfalseになると、
    /// その隙に地図が有効扱いになり、シートや位置情報の許可ダイアログが先に出てしまうため。
    /// - Parameter hasRecordedPlaces: 起動時点で記録が1件以上あるか。起動中に記録が増えても出す時機は変えない
    ///   (新規の人が記録した直後にチュートリアル後扱いへ切り替わらないようにするため)。
    init(userDefaults: UserDefaults = .standard, hasRecordedPlaces: Bool) {
        self.userDefaults = userDefaults
        let isPending = !userDefaults.bool(forKey: Self.seenKey)
            && NewMunicipalityAlertMonitor.loadMode(from: userDefaults) == .off
        let timing: Timing = hasRecordedPlaces ? .afterTutorial : .afterFirstRecord
        self.isPending = isPending
        self.timing = timing
        isPresented = isPending && timing == .afterTutorial
    }

    /// 市区町村の初訪問のお祝いを閉じたときに呼ぶ。最初の記録を待っている人にだけカードを出す。
    /// 待っている間に「設定」画面で自分からモードを選んでいたら、もう案内は要らないので出さない。
    func firstVisitCelebrationDidFinish() {
        guard isPending, timing == .afterFirstRecord else { return }
        guard NewMunicipalityAlertMonitor.loadMode(from: userDefaults) == .off else {
            markSeen()
            return
        }
        isPresented = true
    }

    func markSeen() {
        userDefaults.set(true, forKey: Self.seenKey)
        isPending = false
        isPresented = false
    }
}

/// 初訪問の通知を案内するカード。アップデートで来た人には「追加されました」としてチュートリアルの後に、
/// 新規の人には最初の記録を終えた後に、地図の上へ重ねて出す(文言は`timing`で切り替える)。
/// その場でモードを選べるようにし、選んだ直後に通知・位置情報の許可を求める(何のための許可かが分かる場面のため)。
/// 地図の常駐シートや儀式シートと競合しないよう、シートではなくContentViewのZStackに重ねる(チュートリアルと同じ方式)。
struct NewMunicipalityAlertAnnouncement: View {
    let timing: NewMunicipalityAlertAnnouncementGate.Timing
    let choose: (NewMunicipalityAlertMode) -> Void

    var body: some View {
        ZStack {
            // 裏の地図は操作できない(ContentViewがisActive=falseにしている)ことを、暗くして伝える。
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            ScrollView {
                card
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
            }
            // 大きな文字でもボタンへ届くようスクロールできるようにしつつ、収まる時は中央に置く。
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
    }

    private var card: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(.teal))
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    choose(.municipality)
                } label: {
                    Text("市区町村ごとに通知する")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    choose(.prefecture)
                } label: {
                    Text("都道府県のみ通知する")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button("今はしない") {
                    choose(.off)
                }
                .padding(.top, 4)
            }
            .controlSize(.large)
            .tint(.teal)

            VStack(alignment: .leading, spacing: 8) {
                Label(LocationUsageAssurance.battery, systemImage: "leaf")
                Label(LocationUsageAssurance.privacy, systemImage: "lock.iphone")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("画面右下の歯車の「設定」からいつでも変更できます。オンにすると、通知と位置情報（常に）の許可を確認します。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var title: String {
        switch timing {
        case .afterTutorial: "通知機能が追加されました"
        case .afterFirstRecord: "次の初めての街も、お知らせしましょうか？"
        }
    }

    private var message: String {
        switch timing {
        case .afterTutorial:
            "まだ記録していない市区町村や都道府県に入ると、アプリを閉じていても通知でお知らせします。"
        case .afterFirstRecord:
            "まだ記録していない市区町村や都道府県に入ると、アプリを閉じていても通知でお知らせします。記録し忘れを防げます。"
        }
    }
}

#Preview {
    NewMunicipalityAlertAnnouncement(timing: .afterFirstRecord, choose: { _ in })
}
