#!/usr/bin/env python3
"""OpenStreetMapの名所を、みどころの評価の材料(work/evidence)へ足す。collect_evidence.py の後に実行する。

使い方(リポジトリ直下で): python3 -I SpotMaster/scripts/collect_osm.py [都道府県コード ...]
OSMは判断の参考にするだけで、一覧をそのまま写さない(データのライセンスがODbLのため)。
公開サーバーに負担をかけないよう、都道府県を1つずつ順に問い合わせる。取得済みは work/cache に残る。
"""
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from collect_evidence import Boundaries, CACHE, ROOT, USER_AGENT, cached  # noqa: E402

MAXIMUM_CANDIDATES = 30
ENDPOINT = "https://overpass-api.de/api/interpreter"


def query_prefecture(code):
    # macOS付属のPythonのTLSがこのサーバーと接続できないので、通信はcurlで行う。
    query = f"""[out:json][timeout:170];
    area["ISO3166-2"="JP-{code}"]->.a;
    (nwr(area.a)["tourism"~"^(attraction|viewpoint|museum|gallery|zoo|aquarium|theme_park)$"]["name"];
     nwr(area.a)["historic"~"^(castle|archaeological_site|ruins)$"]["name"];
     nwr(area.a)["natural"~"^(beach|peak|waterfall|cape|hot_spring)$"]["name"]["wikidata"];
     nwr(area.a)["waterway"="waterfall"]["name"];
     nwr(area.a)["leisure"~"^(park|garden)$"]["name"]["wikidata"];
     nwr(area.a)["amenity"="place_of_worship"]["name"]["wikidata"];
     nwr(area.a)["place"="island"]["name"]["wikidata"];);
    out tags center;"""
    for attempt in range(6):
        result = subprocess.run(
            ["curl", "-s", "--max-time", "200", "-A", USER_AGENT, "--data-urlencode", "data@-", ENDPOINT],
            input=query, capture_output=True, text=True,
        )
        try:
            return json.loads(result.stdout)["elements"]
        except (ValueError, KeyError):
            print(f"  {code}: 再試行({attempt + 1})", file=sys.stderr, flush=True)
            time.sleep(30 * (attempt + 1))
    raise RuntimeError(f"取得できません: {code}")


def main():
    wanted = sys.argv[1:]
    for name in sorted(os.listdir(f"{ROOT}/evidence")):
        code = name[:2]
        if wanted and code not in wanted:
            continue
        path = f"{ROOT}/evidence/{name}"
        with open(path, encoding="utf-8") as file:
            evidence = json.load(file)
        if evidence and "osm" in evidence[0]:
            continue
        boundaries = Boundaries(code)
        found = {}
        for element in cached(f"osm_{code}", lambda: query_prefecture(code)):
            tags = element.get("tags", {})
            center = element.get("center") or element
            if "lon" not in center:
                continue
            municipality = boundaries.code_at(center["lon"], center["lat"])
            if not municipality:
                continue
            kind = tags.get("tourism") or tags.get("historic") or tags.get("natural") or tags.get("waterway") \
                or tags.get("leisure") or tags.get("place") or tags.get("amenity")
            # Wikipedia・Wikidataと結び付いているものは、ある程度名の知られた場所とみなして先に並べる。
            weight = ("wikidata" in tags) + ("wikipedia" in tags) + (tags.get("tourism") == "attraction")
            found.setdefault(municipality, {})[tags["name"]] = (kind, weight)
        for item in evidence:
            places = sorted(found.get(item["code"], {}).items(), key=lambda place: -place[1][1])
            item["osm"] = [[name, value[0]] for name, value in places[:MAXIMUM_CANDIDATES]]
        with open(path, "w", encoding="utf-8") as file:
            json.dump(evidence, file, ensure_ascii=False, indent=0)
        print(f"{code}: {sum(1 for item in evidence if item['osm'])}市区町村にOSMあり", flush=True)
        time.sleep(5)
    print("完了", flush=True)


if __name__ == "__main__":
    main()
