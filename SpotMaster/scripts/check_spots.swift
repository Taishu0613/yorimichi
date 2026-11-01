// みどころマスタ(MunicipalitySpots.csv)の検査。形式の間違いと、実在しない場所(AIの書き間違い)を見つける。
//
// 使い方(リポジトリ直下で):
//   swiftc -O SpotMaster/scripts/check_spots.swift -o /tmp/check_spots
//   /tmp/check_spots WAGhack/WAGhack/Resources/MunicipalitySpots.csv LocalGovernmentCodeJapan_Knowledge.csv \
//     BoundaryData/generated/BoundaryData/municipalities/lod2_100m [--format-only] [--code 12101]
//
// 実在の確認はMapKitの検索で、名前で見つかる場所がその市区町村の境界の中にあるかを見る。
// 結果(場所の有無)を人が読むだけで、検索結果そのものはマスタに書き込まない(Appleの規約で地図データは保存できないため)。
// 検索には回数の制限があるので、1件ごとに間を置く。全国分は数時間かかる。
import Foundation
import MapKit

struct Row {
    let line: Int
    let code: String, rank: Int?, name: String, category: String, action: String, reason: String
}

let categories: Set<String> = [
    "shrine", "temple", "castle", "history", "museum", "art", "garden", "view", "waterfront", "nature", "animals",
    "hotSpring", "park", "town", "food", "entertainment", "landmark", "other",
]
/// 画面の1行に収まる長さの目安。
let maximumActionLength = 16, maximumReasonLength = 40, maximumSpotCount = 10
/// 境界データの間引きの誤差。これより境界に近ければ区域の中とみなす(LOD2は100m)。
let boundaryToleranceMeters = 100.0

func parseCSV(_ source: String) -> [[String]] {
    var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
    var iterator = source.makeIterator(), pending: Character? = nil
    while let character = pending ?? iterator.next() {
        pending = nil
        if quoted {
            if character == "\"" {
                let next = iterator.next()
                if next == "\"" { field.append("\"") } else { quoted = false; pending = next }
            } else { field.append(character) }
        } else if character == "\"" { quoted = true }
        else if character == "," { row.append(field); field = "" }
        else if character == "\n" || character == "\r\n" { row.append(field); field = ""; rows.append(row); row = [] }
        else { field.append(character) }
    }
    if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
    return rows
}

func read(_ path: String) -> String {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fatalError("読めません: \(path)") }
    return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else { fatalError("使い方はファイルの先頭を参照") }
let formatOnly = arguments.contains("--format-only")
let onlyCode = arguments.firstIndex(of: "--code").map { arguments[$0 + 1] }

// 市区町村の一覧
var areaNames: [String: (prefecture: String, municipality: String)] = [:]
for row in parseCSV(read(arguments[2])).dropFirst() where row.count == 9 && row[5] != "TRUE" {
    areaNames[row[0]] = (row[1], row[2])
}

// 形式の検査
var problems = 0
func problem(_ text: String) { problems += 1; print("NG \(text)") }
let table = parseCSV(read(arguments[1]))
if table.first != ["code", "rank", "name", "category", "action", "reason"] { problem("1行目の見出しが違います") }
var rowsByCode: [String: [Row]] = [:]
for (index, cells) in table.dropFirst().enumerated() {
    let line = index + 2
    guard cells.count == 6 else { problem("\(line)行目: 列の数が\(cells.count)です"); continue }
    let row = Row(line: line, code: cells[0], rank: Int(cells[1]), name: cells[2], category: cells[3], action: cells[4], reason: cells[5])
    if areaNames[row.code] == nil { problem("\(line)行目: 知らない行政区域コード \(row.code)") }
    if row.rank == nil { problem("\(line)行目: 順位が数字ではありません") }
    if row.name.isEmpty { problem("\(line)行目: 名前が空です") }
    if !categories.contains(row.category) { problem("\(line)行目: 知らない区分 \(row.category)") }
    if row.action.count > maximumActionLength { problem("\(line)行目: 行動の言葉が長すぎます(\(row.action.count)字)") }
    if row.reason.count > maximumReasonLength { problem("\(line)行目: 理由が長すぎます(\(row.reason.count)字)") }
    rowsByCode[row.code, default: []].append(row)
}
for (code, rows) in rowsByCode {
    let label = "\(code) \(areaNames[code]?.municipality ?? "")"
    if rows.count > maximumSpotCount { problem("\(label): \(rows.count)件あります(上限\(maximumSpotCount)件)") }
    if rows.compactMap(\.rank).sorted() != Array(1...rows.count) { problem("\(label): 順位が1からの連番ではありません") }
    if Set(rows.map(\.name)).count != rows.count { problem("\(label): 同じ名前が重複しています") }
}
print("形式: \(rowsByCode.count)市区町村 \(table.count - 1)件 問題\(problems)件")
if formatOnly { exit(problems == 0 ? 0 : 1) }

// 実在の確認
struct Ring { let points: [MKMapPoint] }
struct Polygon { let exterior: Ring, holes: [Ring] }

func polygons(code: String) -> [Polygon] {
    let path = "\(arguments[3])/municipality_\(code.prefix(2))_lod2.geojson"
    guard let data = FileManager.default.contents(atPath: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let features = json["features"] as? [[String: Any]],
          let feature = features.first(where: { ($0["properties"] as? [String: Any])?["c"] as? String == code }),
          let geometry = feature["geometry"] as? [String: Any] else { return [] }
    func ring(_ value: Any) -> Ring {
        Ring(points: (value as? [[Double]] ?? []).map { MKMapPoint(CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])) })
    }
    let shapes = geometry["type"] as? String == "Polygon"
        ? [geometry["coordinates"] as? [Any] ?? []]
        : geometry["coordinates"] as? [[Any]] ?? []
    return shapes.compactMap { shape in
        shape.first.map { Polygon(exterior: ring($0), holes: shape.dropFirst().map(ring)) }
    }
}

func contains(_ ring: Ring, _ point: MKMapPoint) -> Bool {
    var inside = false
    var previous = ring.points.last ?? point
    for current in ring.points {
        if (current.y > point.y) != (previous.y > point.y),
           point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x {
            inside.toggle()
        }
        previous = current
    }
    return inside
}

func distance(_ ring: Ring, _ point: MKMapPoint) -> Double {
    var nearest = Double.infinity
    var previous = ring.points.last ?? point
    for current in ring.points {
        let dx = current.x - previous.x, dy = current.y - previous.y
        let length = dx * dx + dy * dy
        let t = length == 0 ? 0 : max(0, min(1, ((point.x - previous.x) * dx + (point.y - previous.y) * dy) / length))
        nearest = min(nearest, hypot(point.x - previous.x - t * dx, point.y - previous.y - t * dy))
        previous = current
    }
    return nearest
}

func isInside(_ coordinate: CLLocationCoordinate2D, _ shapes: [Polygon]) -> Bool {
    let point = MKMapPoint(coordinate)
    let tolerance = boundaryToleranceMeters * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
    return shapes.contains { shape in
        (contains(shape.exterior, point) || distance(shape.exterior, point) <= tolerance)
            && !shape.holes.contains { contains($0, point) && distance($0, point) > tolerance }
    }
}

func region(of shapes: [Polygon]) -> MKCoordinateRegion {
    let rect = shapes.flatMap(\.exterior.points).reduce(MKMapRect.null) {
        $0.union(MKMapRect(origin: $1, size: MKMapSize(width: 0, height: 0)))
    }
    return MKCoordinateRegion(rect.insetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.1))
}

func normalize(_ text: String) -> String {
    text.precomposedStringWithCompatibilityMapping.lowercased()
        .replacingOccurrences(of: "ヶ", with: "ケ").replacingOccurrences(of: "ツ", with: "ッ")
        .replacingOccurrences(of: "髙", with: "高")
        .filter { !$0.isWhitespace && !"・•-‐〈〉()/".contains($0) }
}

func search(_ query: String, in region: MKCoordinateRegion) -> [MKMapItem] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.region = region
    // 地名の結果(「千代田区」など)が混ざらないよう施設に絞り、市区町村の範囲の外は探さない。
    request.resultTypes = .pointOfInterest
    request.regionPriority = .required
    var result: [MKMapItem]?
    MKLocalSearch(request: request).start { response, _ in result = response?.mapItems ?? [] }
    while result == nil { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    return result ?? []
}

var failed = 0
for code in rowsByCode.keys.sorted() where onlyCode == nil || onlyCode == code {
    guard let area = areaNames[code] else { continue }
    let shapes = polygons(code: code)
    guard !shapes.isEmpty else { print("?? \(code) \(area.municipality): 境界データがありません"); continue }
    let searchRegion = region(of: shapes)
    print("== \(code) \(area.prefecture)\(area.municipality)")
    for row in rowsByCode[code, default: []].sorted(by: { ($0.rank ?? 0) < ($1.rank ?? 0) }) {
        let items = search(row.name, in: searchRegion)
        let insideItems = items.filter { isInside($0.location.coordinate, shapes) }
        let name = normalize(row.name)
        let matching = insideItems.first { item in
            let found = normalize(item.name ?? "")
            return found.contains(name) || name.contains(found)
        }
        if let matching {
            print("OK \(row.rank ?? 0) \(row.name) → \(matching.name ?? "")")
        } else {
            failed += 1
            let nearest = (insideItems.first ?? items.first)?.name ?? "見つからない"
            print("要確認 \(row.rank ?? 0) \(row.name) → 区域内で一致なし(近い結果: \(nearest))")
        }
        Thread.sleep(forTimeInterval: 1.3)
    }
}
print("実在: 要確認\(failed)件")
exit(problems == 0 && failed == 0 ? 0 : 1)
