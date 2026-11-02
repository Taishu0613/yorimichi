// 市区町村マスタの「みどころ(JSON)」の列の検査。形式の間違いと、実在しない場所(AIの書き間違い)を見つける。
//
// 使い方(リポジトリ直下で):
//   swiftc -O SpotMaster/scripts/check_spots.swift -o /tmp/check_spots
//   /tmp/check_spots LocalGovernmentCodeJapan_Knowledge.csv BoundaryData/generated/BoundaryData/municipalities/lod2_150m \
//     [--format-only] [--code 12101] [--results SpotMaster/work/check_results.tsv] [--evidence SpotMaster/work/evidence]
//
// 実在の確認はMapKitの検索で、名前で見つかる場所がその市区町村の境界の中にあるかを見る。
// 結果(場所の有無)を人が読むだけで、検索結果そのものはマスタに書き込まない(Appleの規約で地図データは保存できないため)。
// 検索には回数の制限があるので、1件ごとに間を置く。
// --evidence を渡すと、Wikidataで境界の中にあると分かっている名前は検索を省く。
// --results を渡すと結果を追記し、次に実行したときは確認済みの行を飛ばす(途中で止まっても続きから進む)。
import Foundation
import MapKit

struct Row: Decodable {
    let name: String
    let category: String
    let action: String?
    let reason: String?
}

let categories: Set<String> = [
    "shrine", "temple", "castle", "history", "museum", "art", "garden", "view", "waterfront", "nature", "animals",
    "hotSpring", "park", "town", "food", "entertainment", "landmark", "other",
]
/// 画面の1行に収まる長さの目安。
let maximumActionLength = 16, maximumReasonLength = 40, maximumSpotCount = 10
/// 境界データの間引きの誤差。これより境界に近ければ区域の中とみなす(LOD2は150m)。
let boundaryToleranceMeters = 150.0

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
guard arguments.count >= 3 else { fatalError("使い方はファイルの先頭を参照") }
let formatOnly = arguments.contains("--format-only")
func option(_ name: String) -> String? { arguments.firstIndex(of: name).map { arguments[$0 + 1] } }
let onlyCode = option("--code")
let boundaryFolder = arguments[2]

// 形式の検査
var problems = 0
func problem(_ text: String) { problems += 1; print("NG \(text)") }
var areaNames: [String: (prefecture: String, municipality: String)] = [:]
var rowsByCode: [String: [Row]] = [:]
for cells in parseCSV(read(arguments[1])).dropFirst() {
    guard cells.count == 10 else { problem("\(cells.first ?? "") の列の数が\(cells.count)です"); continue }
    guard cells[5] != "TRUE" else { continue }
    let code = cells[0]
    areaNames[code] = (cells[1], cells[2])
    guard !cells[9].isEmpty else { continue }
    guard let rows = try? JSONDecoder().decode([Row].self, from: Data(cells[9].utf8)) else {
        problem("\(code) \(cells[2]): JSONを読めません")
        continue
    }
    rowsByCode[code] = rows
    if rows.count > maximumSpotCount { problem("\(code) \(cells[2]): \(rows.count)件あります(上限\(maximumSpotCount)件)") }
    if Set(rows.map(\.name)).count != rows.count { problem("\(code) \(cells[2]): 同じ名前が重複しています") }
    for row in rows {
        if row.name.isEmpty { problem("\(code): 名前が空です") }
        if !categories.contains(row.category) { problem("\(code) \(row.name): 知らない区分 \(row.category)") }
        if (row.action ?? "").count > maximumActionLength { problem("\(code) \(row.name): 行動の言葉が長すぎます") }
        if (row.reason ?? "").count > maximumReasonLength { problem("\(code) \(row.name): 理由が長すぎます") }
    }
}
let emptyCount = areaNames.count - rowsByCode.count
print("形式: \(rowsByCode.count)市区町村 \(rowsByCode.values.map(\.count).reduce(0, +))件 空\(emptyCount)市区町村 問題\(problems)件")
if formatOnly { exit(problems == 0 ? 0 : 1) }

// 実在の確認
struct Ring { let points: [MKMapPoint] }
struct Polygon { let exterior: Ring, holes: [Ring] }

var featuresByPrefecture: [String: [[String: Any]]] = [:]

func features(prefecture: String) -> [[String: Any]] {
    if let cached = featuresByPrefecture[prefecture] { return cached }
    let path = "\(boundaryFolder)/municipality_\(prefecture)_lod2.geojson"
    let json = FileManager.default.contents(atPath: path)
        .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let features = json?["features"] as? [[String: Any]] ?? []
    featuresByPrefecture = [prefecture: features]
    return features
}

func polygons(code: String) -> [Polygon] {
    guard let feature = features(prefecture: String(code.prefix(2)))
        .first(where: { ($0["properties"] as? [String: Any])?["c"] as? String == code }),
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

/// Wikidataで境界の中にあると分かっている名前(市区町村コードごと)。
func knownNames() -> [String: Set<String>] {
    guard let folder = option("--evidence") else { return [:] }
    var names: [String: Set<String>] = [:]
    for file in (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [] {
        guard let data = FileManager.default.contents(atPath: "\(folder)/\(file)"),
              let items = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { continue }
        for item in items {
            guard let code = item["code"] as? String, let candidates = item["wikidata"] as? [[Any]] else { continue }
            names[code] = Set(candidates.compactMap { ($0.first as? String).map(normalize) })
        }
    }
    return names
}

let resultsPath = option("--results")
var checked: Set<String> = []
if let resultsPath, let text = try? String(contentsOfFile: resultsPath, encoding: .utf8) {
    for line in text.split(separator: "\n") {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        if fields.count >= 3 { checked.insert("\(fields[0])\t\(fields[1])") }
    }
}

func record(_ code: String, _ name: String, _ status: String, _ detail: String) {
    print("\(status) \(code) \(name) \(detail)")
    guard let resultsPath, let data = "\(code)\t\(name)\t\(status)\t\(detail)\n".data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: resultsPath) { FileManager.default.createFile(atPath: resultsPath, contents: nil) }
    if let handle = FileHandle(forWritingAtPath: resultsPath) {
        handle.seekToEndOfFile()
        handle.write(data)
        handle.closeFile()
    }
}

let known = knownNames()
var failed = 0
for code in rowsByCode.keys.sorted() where onlyCode == nil || onlyCode == code {
    let shapes = polygons(code: code)
    guard !shapes.isEmpty else {
        // 境界のファイルを1つも読めないときは、場所の指定かサンドボックスの問題なので、確認できたことにせず止める。
        if featuresByPrefecture.values.allSatisfy(\.isEmpty) {
            print("NG 境界データを読めません: \(boundaryFolder)(サンドボックスの外で実行してください)")
            exit(2)
        }
        print("?? \(code): 境界データがありません")
        continue
    }
    let searchRegion = region(of: shapes)
    for row in rowsByCode[code, default: []] where !checked.contains("\(code)\t\(row.name)") {
        let name = normalize(row.name)
        if known[code]?.contains(name) == true {
            record(code, row.name, "OK", "wikidata")
            continue
        }
        let items = search(row.name, in: searchRegion)
        let insideItems = items.filter { isInside($0.location.coordinate, shapes) }
        let matching = insideItems.first { item in
            let found = normalize(item.name ?? "")
            return !found.isEmpty && (found.contains(name) || name.contains(found))
        }
        if let matching {
            record(code, row.name, "OK", matching.name ?? "")
        } else {
            failed += 1
            record(code, row.name, "NG", (insideItems.first ?? items.first)?.name ?? "見つからない")
        }
        Thread.sleep(forTimeInterval: 1.3)
    }
}
print("実在: 要確認\(failed)件")
exit(problems == 0 && failed == 0 ? 0 : 1)
