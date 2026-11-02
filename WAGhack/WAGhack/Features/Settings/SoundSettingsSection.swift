import SwiftUI

/// 「設定」画面(SettingsScreen)に置く、BGMと効果音の音量。
/// BGMは流れている曲の音量がそのまま変わるので、効果音だけ指を離したときに試し聴きを鳴らす。
struct SoundSettingsSection: View {
    /// アプリのルートで渡される。プレビューなど渡されない場所では何も出さない。
    @Environment(SoundController.self) private var sound: SoundController?

    var body: some View {
        if let sound {
            Section {
                volumeSlider(
                    title: "BGM",
                    systemImage: "music.note",
                    volume: Binding(
                        get: { sound.backgroundMusicVolume },
                        set: { sound.setBackgroundMusicVolume($0) }
                    )
                )
                volumeSlider(
                    title: "効果音",
                    systemImage: "speaker.wave.2",
                    volume: Binding(
                        get: { sound.soundEffectVolume },
                        set: { sound.setSoundEffectVolume($0) }
                    ),
                    onEditingEnded: { sound.play(.record) }
                )
            } header: {
                PopSectionHeader(title: "サウンド", marker: Pop.yellow)
            } footer: {
                Text("消音モードの間は鳴りません。ほかのアプリで音楽を再生している間は、BGMを止めます。初訪問の通知の音は、iPhone本体の音量に従います。")
            }
        }
    }

    private func volumeSlider(
        title: String,
        systemImage: String,
        volume: Binding<Float>,
        onEditingEnded: @escaping () -> Void = {}
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
            Slider(value: volume, in: 0...1) {
                Text(title)
            } onEditingChanged: { isEditing in
                if !isEditing {
                    onEditingEnded()
                }
            }
        }
    }
}
