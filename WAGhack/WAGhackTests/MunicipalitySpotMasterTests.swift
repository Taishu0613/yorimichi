import Testing
@testable import WAGhack

struct MunicipalitySpotMasterTests {
    @Test func 順位の順に並べて行動の言葉が空なら区分の言葉を使う() throws {
        let source = """
        code,rank,name,category,action,reason
        12101,2,千葉神社,shrine,,
        12101,1,千葉ポートタワー,view,港の景色を眺める,"東京湾を、一望できる"
        13104,1,新宿御苑,garden,,

        """

        let spots = try MunicipalitySpotMaster.parse(source)["12101"]

        #expect(spots?.map(\.name) == ["千葉ポートタワー", "千葉神社"])
        #expect(spots?[0].displayAction == "港の景色を眺める")
        #expect(spots?[0].reason == "東京湾を、一望できる")
        #expect(spots?[1].displayAction == SpotExperience.shrine.actionPhrase)
        #expect(spots?[1].reason == nil)
    }

    @Test func 知らない区分はotherにして上限より多い行は切り捨てる() throws {
        let rows = (1...12).map { "12101,\($0),場所\($0),unknown,," }
        let source = (["code,rank,name,category,action,reason"] + rows).joined(separator: "\n")

        let spots = try #require(try MunicipalitySpotMaster.parse(source)["12101"])

        #expect(spots.count == MunicipalitySpotMaster.maximumSpotCount)
        #expect(spots.first?.experience == .other)
        #expect(spots.first?.displayAction == nil)
    }
}
