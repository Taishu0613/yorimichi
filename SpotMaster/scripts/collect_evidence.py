#!/usr/bin/env python3
"""全国の市区町村について、みどころを評価するための材料を集める。

使い方(リポジトリ直下で): python3 -I SpotMaster/scripts/collect_evidence.py
出力: SpotMaster/work/evidence/<都道府県コード>.json

材料は3つ。どれも保存して同梱してよい範囲のものだけを使う。
- 市区町村マスタの豆知識
- 日本語版Wikipediaの記事の、観光・名所などの節(CC BY-SA。評価の材料にするだけで、文章は写さない)
- Wikidataの、その市区町村の境界の中にある名所(CC0)。何言語のWikipediaに記事があるか(sitelinks)を有名さの目安にする
OpenStreetMapは使わない(ODbLにより、作った一覧の公開義務が生じるため)。
途中で止まっても、取得済みの結果は work/cache に残るので、もう一度実行すれば続きから進む。
"""
import csv
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = "SpotMaster/work"
CACHE = f"{ROOT}/cache"
BOUNDARY = "BoundaryData/generated/BoundaryData/municipalities/lod2_100m"
USER_AGENT = "Yorimichi-SpotMaster/1.0 (https://github.com/Taishu0613/yorimichi; data preparation)"
SECTION_PATTERN = re.compile("観光|名所|旧跡|見どころ|見所|史跡|文化財|スポット|名勝|景勝|祭|イベント|施設|特産|グルメ|温泉|公園|博物館")
MAXIMUM_SECTION_CHARACTERS = 1800
MAXIMUM_WIKIDATA_CANDIDATES = 30
# 同時に投げる問い合わせの数。Wikidataの検索は1接続あたりの上限が5なので、余裕を見て4にする。
WIKIDATA_WORKERS = 4
WIKIPEDIA_WORKERS = 3
# 寄り道の目的になる種類(下位の種類も1段含める)。
PLACE_TYPES = """Q570116 Q845945 Q5393308 Q160742 Q23413 Q33506 Q22698 Q1107656 Q12518 Q11303 Q4989906 Q2319498 Q24354
Q153562 Q43501 Q16970 Q839954 Q207694 Q1440300 Q1497364 Q79007 Q16560 Q34038 Q40080 Q23442 Q8502 Q46831 Q23397
Q35509 Q4421 Q9259 Q44782 Q1021711 Q47521 Q194195 Q1144661 Q2977 Q44539 Q842402 Q215380""".split()


def fetch(url, data=None, attempts=5):
    for attempt in range(attempts):
        try:
            request = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.load(response)
        except Exception as error:  # 通信の失敗は待って取り直す。最後まで駄目なら止めて原因を見せる。
            wait = 5 * (attempt + 1)
            print(f"  再試行({attempt + 1}): {error}", file=sys.stderr, flush=True)
            time.sleep(wait)
    raise RuntimeError(f"取得できません: {url[:120]}")


def cached(name, producer):
    path = f"{CACHE}/{name}.json"
    if os.path.exists(path):
        with open(path, encoding="utf-8") as file:
            return json.load(file)
    value = producer()
    with open(path, "w", encoding="utf-8") as file:
        json.dump(value, file, ensure_ascii=False)
    return value


def sparql(query):
    url = "https://query.wikidata.org/sparql?" + urllib.parse.urlencode({"query": query, "format": "json"})
    return fetch(url)["results"]["bindings"]


def load_municipalities():
    with open("LocalGovernmentCodeJapan_Knowledge.csv", encoding="utf-8-sig", newline="") as file:
        rows = list(csv.reader(file))[1:]
    return [
        {"code": row[0], "prefecture": row[1], "name": row[2], "history": row[7], "famous": row[8]}
        for row in rows if row[5] != "TRUE"
    ]


def article_titles():
    """全国地方公共団体コード(P429)から、市区町村のWikipediaの記事名を一度に引く。"""
    rows = sparql("""SELECT ?code ?title WHERE {
      ?item wdt:P429 ?code .
      ?article schema:about ?item ; schema:isPartOf <https://ja.wikipedia.org/> ; schema:name ?title .
    }""")
    # P429は検査数字付きの6桁のことがあるので、先頭5桁で引く。
    return {row["code"]["value"][:5]: row["title"]["value"] for row in rows}


def wikipedia_sections(title):
    url = "https://ja.wikipedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "formatversion": 2, "prop": "extracts", "explaintext": 1,
        "exsectionformat": "wiki", "redirects": 1, "titles": title,
    })
    pages = fetch(url).get("query", {}).get("pages", [])
    text = pages[0].get("extract", "") if pages else ""
    parts = re.split(r"\n(={2,4} .+? ={2,4})\n", text)
    picked = []
    for heading, body in zip(parts[1::2], parts[2::2]):
        if SECTION_PATTERN.search(heading) and body.strip():
            picked.append(heading.strip("= ") + ": " + re.sub(r"\s+", " ", body.strip()))
    return "\n".join(picked)[:MAXIMUM_SECTION_CHARACTERS]


def ring_contains(ring, x, y):
    inside = False
    x2, y2 = ring[-1][:2]
    for point in ring:
        x1, y1 = point[:2]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
        x2, y2 = x1, y1
    return inside


class Boundaries:
    """都道府県の境界。市区町村ごとの多角形と外接矩形を持つ。"""

    def __init__(self, prefecture_code):
        with open(f"{BOUNDARY}/municipality_{prefecture_code}_lod2.geojson", encoding="utf-8") as file:
            features = json.load(file)["features"]
        self.areas = []
        for feature in features:
            geometry = feature["geometry"]
            polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
            points = [point for polygon in polygons for point in polygon[0]]
            box = (min(p[0] for p in points), min(p[1] for p in points), max(p[0] for p in points), max(p[1] for p in points))
            self.areas.append((feature["properties"]["c"], polygons, box))

    def box(self):
        return (min(a[2][0] for a in self.areas), min(a[2][1] for a in self.areas),
                max(a[2][2] for a in self.areas), max(a[2][3] for a in self.areas))

    def code_at(self, x, y):
        for code, polygons, box in self.areas:
            if not (box[0] <= x <= box[2] and box[1] <= y <= box[3]):
                continue
            for polygon in polygons:
                if ring_contains(polygon[0], x, y) and not any(ring_contains(hole, x, y) for hole in polygon[1:]):
                    return code
        return None


def wikidata_tile(west, south, east, north):
    values = " ".join(f"wd:{item}" for item in PLACE_TYPES)
    return sparql(f"""SELECT ?item ?label ?links ?coord (SAMPLE(?typeName) AS ?type) WHERE {{
      SERVICE wikibase:box {{ ?item wdt:P625 ?coord .
        bd:serviceParam wikibase:cornerSouthWest "Point({west} {south})"^^geo:wktLiteral ;
                        wikibase:cornerNorthEast "Point({east} {north})"^^geo:wktLiteral . }}
      VALUES ?want {{ {values} }}
      ?item wdt:P31/wdt:P279? ?want ; wikibase:sitelinks ?links ; rdfs:label ?label .
      FILTER(LANG(?label) = "ja")
      FILTER NOT EXISTS {{ ?item wdt:P576 ?closed }}
      FILTER NOT EXISTS {{ ?item wdt:P3999 ?closed2 }}
      OPTIONAL {{ ?item wdt:P31 ?t . ?t rdfs:label ?typeName . FILTER(LANG(?typeName) = "ja") }}
    }} GROUP BY ?item ?label ?links ?coord""")


def wikidata_candidates(prefecture_code, boundaries):
    """都道府県の範囲を升目に分けて問い合わせ、境界の中の市区町村へ振り分ける。"""
    west, south, east, north = boundaries.box()
    # 離島で範囲が広い都道県があるので、升目の大きさは固定にする(1回の問い合わせを軽くするため)。
    tile = 0.5
    columns = int((east - west) / tile) + 1
    lines = int((north - south) / tile) + 1
    tiles = []
    for column in range(columns):
        for line in range(lines):
            box = (round(west + column * tile, 4), round(south + line * tile, 4),
                   round(west + (column + 1) * tile, 4), round(south + (line + 1) * tile, 4))
            has_land = any(a[2][0] <= box[2] and box[0] <= a[2][2] and a[2][1] <= box[3] and box[1] <= a[2][3]
                           for a in boundaries.areas)
            if has_land:
                tiles.append((f"wd_{prefecture_code}_{column}_{line}", box))

    with ThreadPoolExecutor(WIKIDATA_WORKERS) as executor:
        results = executor.map(lambda item: cached(item[0], lambda: wikidata_tile(*item[1])), tiles)
    found = {}
    for rows in results:
        for row in rows:
            x, y = map(float, row["coord"]["value"][6:-1].split())
            code = boundaries.code_at(x, y)
            if code:
                found.setdefault(code, {})[row["item"]["value"]] = [
                    row["label"]["value"], row.get("type", {}).get("value", ""), int(row["links"]["value"])
                ]
    return {code: sorted(items.values(), key=lambda item: -item[2])[:MAXIMUM_WIKIDATA_CANDIDATES]
            for code, items in found.items()}


def main():
    os.makedirs(CACHE, exist_ok=True)
    os.makedirs(f"{ROOT}/evidence", exist_ok=True)
    municipalities = load_municipalities()
    titles = cached("article_titles", article_titles)
    print(f"記事名: {len(titles)}件", flush=True)
    by_prefecture = {}
    for municipality in municipalities:
        by_prefecture.setdefault(municipality["code"][:2], []).append(municipality)
    for prefecture_code in sorted(by_prefecture):
        path = f"{ROOT}/evidence/{prefecture_code}.json"
        if os.path.exists(path):
            continue
        boundaries = Boundaries(prefecture_code)
        candidates = wikidata_candidates(prefecture_code, boundaries)

        def build(municipality):
            code = municipality["code"]
            title = titles.get(code)
            sections = cached(f"wp_{code}", lambda: wikipedia_sections(title)) if title else ""
            return {**municipality, "wikipedia": sections, "wikidata": candidates.get(code, [])}

        with ThreadPoolExecutor(WIKIPEDIA_WORKERS) as executor:
            evidence = list(executor.map(build, by_prefecture[prefecture_code]))
        with open(path, "w", encoding="utf-8") as file:
            json.dump(evidence, file, ensure_ascii=False, indent=0)
        with_data = sum(1 for item in evidence if item["wikidata"])
        print(f"{prefecture_code}: {len(evidence)}市区町村 Wikidataあり{with_data}", flush=True)
    print("完了", flush=True)


if __name__ == "__main__":
    main()
