import SwiftUI

/// 通知・有料機能・地図の出典など、旅の記録そのものではない項目をまとめた画面。
/// 常駐シート(フッター)の右端の歯車ボタンから、シートで開く。
///
/// 以前はこれらを「旅の記録」の一覧の末尾に並べていたが、記録を見返す画面に設定が混ざって
/// 埋もれていたため、Apple Musicのタブバーの右端の検索ボタンのように、主役(旅の記録)と分けて置く。
struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NewMunicipalityAlertSettingsSection()
                AutoRecordSettingsSection()

                // マップの市区町村ポリゴンの出典(CC BY 4.0の表示義務)。地図の上は操作部品で埋まっているため、ここに置く。
                Section {
                    BoundaryAttributionView()
                } header: {
                    Text("地図の境界データ")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsScreen()
}
