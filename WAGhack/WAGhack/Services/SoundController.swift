import AVFoundation
import Observation
import OSLog
import SwiftUI

/// 鳴らすBGM。ファイルは`Resources/Sounds`に置く。
enum BackgroundMusic {
    /// キック無しの控えめな曲。地図は長く開いたままになるので、通常はこちらを流す。
    case calm
    /// キック入りの明るい曲。短い間だけ見るチュートリアルで流す。
    case main

    fileprivate var fileName: String {
        switch self {
        case .calm: "bgm_calm_loop"
        case .main: "bgm_main_loop"
        }
    }
}

/// 操作や記録の結果に合わせて鳴らす効果音。ファイルは`Resources/Sounds`に置く。
enum SoundEffect: CaseIterable {
    /// 初めての市区町村に入って誘いシートが出た、または節目(25/50/75/100%)の達成・都道府県や日本の記録。
    case celebration
    /// 初めての市区町村の記録で、地図の区域が塗られた。
    case fill
    /// 再訪問の更新。
    case record
    /// 画面のタップ(`TapSoundObserver`)と地図のピンの選択。
    case tap

    fileprivate var fileName: String {
        switch self {
        case .celebration: "sfx_first_visit"
        case .fill: "sfx_fill"
        case .record: "sfx_record"
        case .tap: "sfx_tap"
        }
    }
}

/// BGMと効果音の再生、およびその音量の設定を唯一持つ。アプリのルートで作り、environmentで渡す。
///
/// 音声セッションは`.ambient`にする。移動中に聴いている音楽や地図アプリの案内を止めないことを優先するため、
/// `.playback`のように他のアプリの音を止めず、消音スイッチにも従う。
/// BGMは他のアプリの音と重なると聞きづらいので、Appleの推奨どおり`secondaryAudioShouldBeSilencedHint`で譲る。
///
/// アプリは位置の変化で裏でも起動される(`NewMunicipalityAlertMonitor`)。裏で音を鳴らさないよう、
/// 音声の準備はinitではなく、画面が初めて前面に出たとき(`handleScenePhase`)に行う。
@MainActor
@Observable
final class SoundController {
    private(set) var backgroundMusicVolume: Float
    private(set) var soundEffectVolume: Float

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "com.wakasugi.yorimichi", category: "Sound")
    @ObservationIgnored private var isInForeground = false
    @ObservationIgnored private var isSessionConfigured = false
    @ObservationIgnored private var backgroundMusic = BackgroundMusic.calm
    @ObservationIgnored private var backgroundMusicPlayer: AVAudioPlayer?
    /// 効果音は続けて重ねて鳴らす場面が無いので、種類ごとに1つ持って使い回す。
    @ObservationIgnored private var soundEffectPlayers: [SoundEffect: AVAudioPlayer] = [:]

    /// 非圧縮のWAVのまま使う。圧縮するとループの継ぎ目に無音が入ることがあるため。
    private static let fileExtension = "wav"
    /// 地図を開くたびに曲が急に鳴り出さないよう、再生の始めだけ音量を上げていく。
    private static let fadeInDuration: TimeInterval = 1

    /// キーを変えると保存済みの音量が失われるので変えないこと。
    private static let backgroundMusicVolumeKey = "sound.backgroundMusicVolume"
    private static let soundEffectVolumeKey = "sound.soundEffectVolume"
    private static let defaultBackgroundMusicVolume: Float = 0.25
    private static let defaultSoundEffectVolume: Float = 0.8

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        backgroundMusicVolume = userDefaults.object(forKey: Self.backgroundMusicVolumeKey) as? Float
            ?? Self.defaultBackgroundMusicVolume
        soundEffectVolume = userDefaults.object(forKey: Self.soundEffectVolumeKey) as? Float
            ?? Self.defaultSoundEffectVolume
    }

    // MARK: - 音量の設定

    func setBackgroundMusicVolume(_ volume: Float) {
        backgroundMusicVolume = volume
        userDefaults.set(volume, forKey: Self.backgroundMusicVolumeKey)
        updateBackgroundMusic()
    }

    func setSoundEffectVolume(_ volume: Float) {
        soundEffectVolume = volume
        userDefaults.set(volume, forKey: Self.soundEffectVolumeKey)
    }

    // MARK: - 再生

    func play(_ effect: SoundEffect) {
        guard soundEffectVolume > 0, let player = soundEffectPlayer(for: effect) else { return }
        player.volume = soundEffectVolume
        player.currentTime = 0
        player.play()
    }

    func setBackgroundMusic(_ music: BackgroundMusic) {
        guard music != backgroundMusic else { return }
        backgroundMusic = music
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
        updateBackgroundMusic()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isInForeground = true
            configureSessionIfNeeded()
        case .background:
            isInForeground = false
        default:
            // 通知センターを引き出すなど、一時的に.inactiveになっただけなら鳴らし続ける。
            return
        }
        updateBackgroundMusic()
    }

    /// 他のアプリの音が始まった・終わったらBGMを合わせる。通知は前面にいる間だけ届き、
    /// 裏にいる間の変化は前面に戻ったときの`updateBackgroundMusic`で拾う。
    func monitorOtherAudio() async {
        for await _ in NotificationCenter.default.notifications(named: AVAudioSession.silenceSecondaryAudioHintNotification) {
            updateBackgroundMusic()
        }
    }

    // MARK: - 内部処理

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            isSessionConfigured = true
        } catch {
            // 音が出ないだけでアプリの機能には影響しないため、ログに残して次に前面へ戻ったときに再試行する。
            logger.error("音声セッションの準備に失敗しました: \(error.localizedDescription, privacy: .public)")
            return
        }
        // 最初の1回で読み込みに時間を取られると、音が触覚より遅れるので先に読んでおく。
        for effect in SoundEffect.allCases {
            _ = soundEffectPlayer(for: effect)
        }
    }

    private func updateBackgroundMusic() {
        let isOtherAudioPlaying = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        guard isInForeground, backgroundMusicVolume > 0, !isOtherAudioPlaying else {
            backgroundMusicPlayer?.pause()
            return
        }
        guard let player = backgroundMusicPlayerIfAvailable() else { return }
        if player.isPlaying {
            player.volume = backgroundMusicVolume
        } else {
            player.volume = 0
            player.play()
            player.setVolume(backgroundMusicVolume, fadeDuration: Self.fadeInDuration)
        }
    }

    private func backgroundMusicPlayerIfAvailable() -> AVAudioPlayer? {
        if let backgroundMusicPlayer {
            return backgroundMusicPlayer
        }
        let player = makePlayer(fileName: backgroundMusic.fileName)
        player?.numberOfLoops = -1
        backgroundMusicPlayer = player
        return player
    }

    private func soundEffectPlayer(for effect: SoundEffect) -> AVAudioPlayer? {
        if let player = soundEffectPlayers[effect] {
            return player
        }
        let player = makePlayer(fileName: effect.fileName)
        soundEffectPlayers[effect] = player
        return player
    }

    private func makePlayer(fileName: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: Self.fileExtension) else {
            logger.error("音声ファイルが見つかりません: \(fileName, privacy: .public)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            logger.error("音声ファイルを開けません: \(fileName, privacy: .public) \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
