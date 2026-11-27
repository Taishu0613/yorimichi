import SwiftData
import SwiftUI

struct SavedPlacesScreen: View {
    /// 踏破率の集計。持ち主の`MapScreen`が記録の増減に合わせて計算し直したものを受け取る。
    ///
    /// この画面はシートを広げるたびに作り直される。以前はここで全市区町村(約2,000件)を`@Query`で
    /// 読み込んで集計し直しており、それだけでメインスレッドが約0.1秒止まり(シミュレータで計測)、
    /// シートが広がるアニメーションが引っかかって見えていた。同じ集計を2か所で持たないためにも受け取る形にしている。
    let summary: ExplorationSummary

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedPlace.savedAt, order: .reverse) private var savedPlaces: [SavedPlace]
    @State private var store = SavedPlacesStore()
    /// マップのシート内でだけ渡される。プレビューなど渡されない場所では地図を出さない。
    @Environment(SilhouetteMapStore.self) private var silhouetteStore: SilhouetteMapStore?
    @State private var isPresentingShare = false

    var body: some View {
        let excludedPlaces = store.excludedPlaces(savedPlaces, summary: summary)

        // マップのシート内NavigationStackにpushされる前提なので、自前のNavigationStackは持たない。
        // 市区町村詳細と同じPOPなカードを並べるため、ListではなくScrollViewにする。
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        ExplorationProgressCard(
                            title: "日本の訪れた都道府県",
                            progress: summary.prefectureProgress,
                            unit: "都道府県",
                            emphasizesCount: true
                        )
                        // 読み込み前も枠は確保し、地図が現れたときに文字の折り返しが変わって揺れないようにする。
                        Group {
                            if let japanMap = silhouetteStore?.japanMap {
                                SilhouetteMapView(map: japanMap, visitedCodes: Set(summary.visitedPrefectures.map(\.code)))
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: SilhouetteMapStore.progressMapSize, height: SilhouetteMapStore.progressMapSize)
                        .padding(.top, 8)
                        .animation(.easeOut(duration: 0.25), value: silhouetteStore?.japanMap != nil)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "\(summary.progress.visited) / \(summary.progress.total) 市区町村を訪問",
                            systemImage: "building.2"
                        )
                        Label(
                            "\(summary.designatedCityProgress.visited) / \(summary.designatedCityProgress.total) 政令指定都市を訪問",
                            systemImage: "building.columns"
                        )
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pop.ink)
                }
                .padding(16)
                .popCard(shadow: Pop.yellow.opacity(0.7))

                ShareMapEntryCard { isPresentingShare = true }

                PopFootnote("都道府県を記録するか、1つでも市区町村を訪れると制覇としてカウントします。政令指定都市は区単位で数え、区を1つ訪れると市も訪問済みになります。")

                // バッジは地図が主役のまま、旅の記録から自然に辿れるようにする(常設のタブやフッターの項目は増やさない)。
                BadgeEntryCard()

                PopSectionHeader(title: "記録した都道府県")

                if summary.visitedPrefectures.isEmpty {
                    Label("マップの「この場所を記録する」から旅をはじめよう", systemImage: "location.circle")
                        .font(.subheadline)
                        .foregroundStyle(Pop.muted)
                }

                ForEach(summary.visitedPrefectures) { prefecture in
                    PopNavigationCard {
                        PrefectureExplorationScreen(prefectureCode: prefecture.code, name: prefecture.name)
                    } label: {
                        PrefectureExplorationRow(prefecture: prefecture)
                    }
                }

                if !excludedPlaces.isEmpty {
                    PopSectionHeader(title: "踏破率に含まれない記録", marker: Pop.themeSoft)
                    ForEach(excludedPlaces) { place in
                        PopNavigationCard {
                            MunicipalityDetailScreen(municipality: place.municipality, fallbackName: place.address)
                        } label: {
                            Text(place.displayName)
                                .font(.headline)
                                .foregroundStyle(Pop.ink)
                        }
                        // カードはListのスワイプ削除が使えないため、長押しのメニューから削除する。
                        .contextMenu {
                            Button("記録を削除", systemImage: "trash", role: .destructive) {
                                store.delete([place], from: modelContext)
                            }
                        }
                    }
                    PopFootnote("区を特定できない市の記録や、市区町村が未確定の記録です。長押しで削除できます。")
                }

                // 通知・有料機能・地図の出典は、フッターの歯車から開く設定画面(SettingsScreen)に置く。
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        // ナビゲーションバーの裏と下端まで白く塗り、シートのガラスが透けて灰色っぽく見えないようにする。
        .background(Pop.paper.ignoresSafeArea())
        .task { await silhouetteStore?.loadJapanMapIfNeeded() }
        .navigationTitle("旅の記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("地図をシェア", systemImage: "square.and.arrow.up") { isPresentingShare = true }
            }
        }
        .sheet(isPresented: $isPresentingShare) {
            // 開いた時点の集計でカードを作る。シートを開いている間に記録が増えることはほぼ無く、
            // 増えても次に開いたときに反映されれば十分なため。
            ShareMapSheet(content: ShareCardContent(summary: summary, date: .now), silhouetteStore: silhouetteStore)
        }
        .alert("削除できませんでした", isPresented: Binding(
            get: { store.deletionErrorMessage != nil },
            set: { if !$0 { store.deletionErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.deletionErrorMessage ?? "不明なエラーが発生しました。")
        }
    }
}

/// 旅の記録の進捗カードのすぐ下に置く「地図をシェア」の入り口。ツールバーの共有ボタンと同じシートを開く。
/// ツールバーのボタンだけでは気づかれにくいため、塗った地図を見ているこの位置にも置く。
private struct ShareMapEntryCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PopIconBadge(systemImage: "square.and.arrow.up", fill: Pop.themeSoft, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("地図をシェア")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Pop.ink)
                    Text("訪れた市区町村を塗った日本地図を画像にできます")
                        .font(.caption)
                        .foregroundStyle(Pop.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(Pop.muted)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .popCard(shadow: Pop.theme.opacity(0.3))
            .contentShape(RoundedRectangle(cornerRadius: Pop.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SavedPlacesScreen(summary: ExplorationSummary(prefectures: [], eligibleCodes: []))
    }
    .modelContainer(for: [SavedPlace.self, Municipality.self, VisitedPrefecture.self], inMemory: true)
}
