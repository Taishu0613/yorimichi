import PhotosUI
import SwiftUI

// シェア画面(`ShareCardSheet`)の選択肢。状態は持たず、シェア画面の状態をBindingで受け取って変えるだけ。

/// 「全国 / 都道府県 / 政令指定都市」と、都道府県・政令指定都市ならどれをシェアするか。
struct ShareCardRegionScopeControls: View {
    let candidates: ShareScopeCandidates
    @Binding var kind: ShareScopeKind
    @Binding var prefectureCode: String?
    @Binding var cityCode: String?

    var body: some View {
        let kinds = candidates.availableKinds
        // まだどこも訪れていないときは全国しか無いので、範囲の選択は出さない。
        if kinds.count > 1 {
            ShareCardLabeledControl("範囲") {
                Picker("範囲", selection: $kind) {
                    ForEach(kinds) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        switch kind {
        case .japan:
            EmptyView()
        case .prefecture:
            ShareCardMenuPicker(
                title: "都道府県",
                selection: Binding(get: { prefectureCode ?? candidates.prefectures.first?.code ?? "" }, set: { prefectureCode = $0 }),
                options: candidates.prefectures.map { ($0.code, "\($0.name)　\($0.progress.percentageText)") }
            )
        case .designatedCity:
            ShareCardMenuPicker(
                title: "政令指定都市",
                selection: Binding(get: { cityCode ?? candidates.designatedCities.first?.code ?? "" }, set: { cityCode = $0 }),
                options: candidates.designatedCities.map { ($0.code, "\($0.name)　\($0.progress.visited)/\($0.progress.total)区") }
            )
        }
    }
}

/// 見出しと右寄せのメニューの1行。都道府県・政令指定都市・載せるスポットを選ぶ。
struct ShareCardMenuPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    init(title: String, selection: Binding<Value>, options: [(Value, String)]) {
        self.title = title
        _selection = selection
        self.options = options.map { (value: $0.0, label: $0.1) }
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Pop.ink)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { Text($0.label).tag($0.value) }
            }
            .pickerStyle(.menu)
            .tint(Pop.theme)
        }
    }
}

/// 項目が少ない選択肢のセグメント(塗り・カードの種類・レイアウト・箱の見た目)。
struct ShareCardSegmentedControl<Value: Hashable & Identifiable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String

    var body: some View {
        ShareCardLabeledControl(title) {
            Picker(title, selection: $selection) {
                ForEach(options) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// 背景の写真を選ぶ・外す。写真はどのカードでも全面の背景なので、まだ無ければ「写真を選ぶ」を目立たせる。
struct ShareCardPhotoControls: View {
    @Binding var photoItem: PhotosPickerItem?
    @Binding var photo: UIImage?
    /// 写真を読み込めなかったときの案内。
    let errorMessage: String?

    var body: some View {
        ShareCardLabeledControl("背景") {
            HStack(spacing: 10) {
                if photo == nil {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("写真を選ぶ", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Pop.theme)
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("写真を変える", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .tint(Pop.theme)
                    Button("写真を外す", systemImage: "xmark.circle") {
                        photoItem = nil
                        photo = nil
                    }
                    .buttonStyle(.bordered)
                    .tint(Pop.muted)
                }
            }
            if photo == nil {
                // 写真が無い間は、その範囲の本物の地図を薄く敷いて描いている。
                Text("写真を選ぶと、写真が主役のカードになります(今は地図を敷いています)")
                    .font(.footnote)
                    .foregroundStyle(Pop.muted)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// 「ステッカーを貼る」。写真を選ぶと、その写真の上に形・名前・数字のステッカーを貼る画面(`ShareStickerEditor`)を開く。
struct ShareCardStickerButton: View {
    @Binding var photoItem: PhotosPickerItem?

    var body: some View {
        ShareCardLabeledControl("ステッカー") {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("ステッカーを貼る", systemImage: "sparkles.rectangle.stack")
            }
            .buttonStyle(.bordered)
            .tint(Pop.theme)
            Text("写真を選ぶと、その上に形と名前のステッカーを貼って、指で動かしたり大きさを変えたりできます")
                .font(.footnote)
                .foregroundStyle(Pop.muted)
        }
    }
}
