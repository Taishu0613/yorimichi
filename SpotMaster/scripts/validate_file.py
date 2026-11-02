#!/usr/bin/env python3
"""スポットのJSONファイルを1つ検査する。使い方: python3 validate_file.py spots/97_tokyo_web.json"""
import json, sys
CATEGORIES = set("shrine temple castle history museum art garden view waterfront nature animals hotSpring park town food entertainment landmark other".split())
data = json.load(open(sys.argv[1], encoding="utf-8"))
problems = []
for code, spots in data.items():
    if len(spots) > 10: problems.append(f"{code}: {len(spots)}件")
    if len({s['name'] for s in spots}) != len(spots): problems.append(f"{code}: 名前の重複")
    for s in spots:
        if set(s) != {"name", "category", "action", "reason"}: problems.append(f"{code} {s}: 項目が違う")
        if s.get("category") not in CATEGORIES: problems.append(f"{code} {s.get('name')}: 区分")
        if len(s.get("action", "")) > 16: problems.append(f"{code} {s.get('name')}: actionが{len(s['action'])}字")
        if len(s.get("reason", "")) > 40: problems.append(f"{code} {s.get('name')}: reasonが{len(s['reason'])}字")
print(f"{len(data)}市区町村 {sum(map(len, data.values()))}件 問題{len(problems)}件")
print("\n".join(problems[:40]))
