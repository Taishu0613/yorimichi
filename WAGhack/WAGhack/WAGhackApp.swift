//
//  WAGhackApp.swift
//  WAGhack
//
//  Created by 若杉泰周 on 2026/08/23.
//

import SwiftUI
import SwiftData
import TipKit
import os

@main
struct WAGhackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedPlace.self,
            Municipality.self,
            VisitedPrefecture.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("SwiftDataの準備に失敗しました: \(error)")
        }
    }()

    /// 初めての市区町村に入ったときの通知。位置の変化で裏で起動し直された場合も位置を受け取れるよう、
    /// 画面(Scene)が作られるのを待たずアプリの初期化で監視を始め直す。
    @State private var newMunicipalityAlert: NewMunicipalityAlertMonitor
    /// 有料機能(初訪問の自動記録)の解放状態。購入の更新を取りこぼさないよう、これも起動直後に受け取りを始める。
    @State private var premiumStore: PremiumStore
    /// BGMと効果音、その音量の設定。
    @State private var soundController = SoundController()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let premiumStore = PremiumStore()
        premiumStore.start()
        let monitor = NewMunicipalityAlertMonitor(modelContainer: sharedModelContainer, premiumStore: premiumStore)
        monitor.startIfEnabled()
        _premiumStore = State(initialValue: premiumStore)
        _newMunicipalityAlert = State(initialValue: monitor)
        Self.configureTips()
    }

    /// 初めての案内(TipKit。図鑑の「カードにしてシェア」など)。案内は1つずつしか無いので、出す間隔は空けない。
    /// 準備に失敗しても案内が出ないだけなので、記録して続ける。
    private static func configureTips() {
        do {
            try Tips.configure([.displayFrequency(.immediate)])
        } catch {
            Logger(subsystem: "com.wakasugi.yorimichi", category: "Tips")
                .error("案内(TipKit)を準備できませんでした: \(String(describing: error), privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContainer: sharedModelContainer)
                .environment(newMunicipalityAlert)
                .environment(premiumStore)
                .environment(soundController)
                .task { await soundController.monitorOtherAudio() }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            soundController.handleScenePhase(phase)
        }
    }
}
