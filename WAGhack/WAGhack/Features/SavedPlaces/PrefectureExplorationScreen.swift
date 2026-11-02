import SwiftData
import SwiftUI

struct PrefectureExplorationScreen: View {
    let prefectureCode: String
    let name: String

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Municipality.code) private var municipalities: [Municipality]
    @Query private var savedPlaces: [SavedPlace]
    @Query private var visitedPrefectures: [VisitedPrefecture]
    @State private var store = SavedPlacesStore()
    /// マップのシート内でだけ渡される。プレビューなど渡されない場所では地図を出さない。
    @Environment(SilhouetteMapStore.self) private var silhouetteStore: SilhouetteMapStore?

    var body: some View {
        let summary = store.summary(municipalities: municipalities, savedPlaces: savedPlaces, visitedPrefectures: visitedPrefectures)
        let prefecture = summary.prefectures.first { $0.code == prefectureCode }

        // 旅の記録・市区町村詳細と同じPOPなカードを並べるため、ListではなくScrollViewにする。
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let prefecture {
                    HStack(alignment: .top, spacing: 12) {
                        ExplorationProgressCard(title: "\(name)の市区町村制覇率", progress: prefecture.progress)
                        // 読み込み前も枠は確保し、地図が現れたときに文字の折り返しが変わって揺れないようにする。
                        Group {
                            if let prefectureMap = silhouetteStore?.prefectureMaps[prefectureCode] {
                                // 塗りを隣の踏破率と一致させるため、踏破率と同じ訪問済みコードを使う。
                                SilhouetteMapView(map: prefectureMap, visitedCodes: prefecture.visitedCodes)
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: SilhouetteMapStore.progressMapSize, height: SilhouetteMapStore.progressMapSize)
                        .padding(.top, 8)
                        .animation(.easeOut(duration: 0.25), value: silhouetteStore?.prefectureMaps[prefectureCode] != nil)
                    }
                    .padding(16)
                    .popCard(shadow: Pop.yellow.opacity(0.7))

                    let cities = prefecture.designatedCities.filter(\.isVisited)
                    if !cities.isEmpty {
                        PopSectionHeader(title: "政令指定都市", marker: Pop.themeSoft)
                        ForEach(cities) { city in
                            PopNavigationCard {
                                MunicipalityDetailScreen(
                                    municipality: municipalities.first { $0.code == city.code },
                                    fallbackName: city.name,
                                    designatedCity: city
                                )
                            } label: {
                                DesignatedCityExplorationRow(city: city)
                            }
                        }
                        PopFootnote("区を1つ訪れると市も訪問済みになり、地図で市の外周が水色の線で囲まれます。")
                    }

                    PopSectionHeader(title: "訪れた市区町村")
                    let entries = prefecture.visitedMunicipalities
                    if entries.isEmpty {
                        Text("マップの「この場所を記録する」から旅をはじめよう")
                            .font(.subheadline)
                            .foregroundStyle(Pop.muted)
                    }
                    ForEach(entries) { entry in
                        if let municipality = municipalities.first(where: { $0.code == entry.code }) {
                            PopNavigationCard {
                                MunicipalityDetailScreen(municipality: municipality, fallbackName: entry.name)
                            } label: {
                                MunicipalityExplorationRow(name: entry.name, trivia: municipality.famousThingsTrivia)
                            }
                            // カードはListのスワイプ削除が使えないため、長押しのメニューから削除する。
                            .contextMenu {
                                Button("訪問を削除", systemImage: "trash", role: .destructive) {
                                    let visits = savedPlaces.filter { $0.municipality?.code == entry.code }
                                    store.delete(visits, from: modelContext)
                                }
                            }
                        }
                    }
                    PopFootnote("訪れた市区町村がここに集まります。みどころは訪問後に確認できます。長押しで訪問を削除できます。")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        // ナビゲーションバーの裏と下端まで白く塗り、シートのガラスが透けて灰色っぽく見えないようにする。
        .background(Pop.paper.ignoresSafeArea())
        .task { await silhouetteStore?.loadPrefectureMapIfNeeded(code: prefectureCode) }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
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

/// 政令指定都市の1行。色は地図の市の外周(`DesignatedCityStyle`)と同じ青にそろえる。
private struct DesignatedCityExplorationRow: View {
    let city: DesignatedCityExploration

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: city.isComplete ? "crown.fill" : "building.columns.fill")
                .foregroundStyle(DesignatedCityStyle.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(city.name).font(.headline.weight(.heavy))
                    Spacer()
                    Text("\(city.progress.visited) / \(city.progress.total) 区")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .foregroundStyle(Pop.ink)
                PopProgressBar(fraction: city.progress.fraction, fill: DesignatedCityStyle.color)
                    .accessibilityLabel("区の踏破率")
            }
        }
    }
}

private struct MunicipalityExplorationRow: View {
    let name: String
    let trivia: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Pop.ink)
                Text(trivia.isEmpty ? "訪問済み" : trivia)
                    .font(.caption)
                    .foregroundStyle(Pop.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
