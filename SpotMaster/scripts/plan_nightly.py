#!/usr/bin/env python3
"""残りの都道府県を、夜ごとの作業量がそろうように分ける。

使い方(リポジトリ直下で): python3 SpotMaster/scripts/plan_nightly.py [夜の数]
出力: SpotMaster/lists/nightly_plan.json

作業量は「市区町村の数＋ネット検索の数」で見積もる。1夜の量を超える都道府県は分割する(北海道など)。
作成済みの市区町村(SpotMaster/work/spots の中のもの)は飛ばす。
"""
import glob
import json
import os
import sys

WORK = "SpotMaster/work"


def main(nights):
    with open("SpotMaster/lists/article_targets.json", encoding="utf-8") as file:
        targets = json.load(file)
    web_codes = set(targets["urban"]) | set(targets["tourist"])

    done = set()
    for path in glob.glob(f"{WORK}/spots/*.json"):
        with open(path, encoding="utf-8") as file:
            done.update(json.load(file))

    units = []
    for path in sorted(glob.glob(f"{WORK}/evidence/*.json")):
        with open(path, encoding="utf-8") as file:
            evidence = json.load(file)
        codes = [item["code"] for item in evidence if item["code"] not in done]
        if codes:
            units.append({"prefecture": os.path.basename(path)[:2], "name": evidence[0]["prefecture"], "codes": codes})

    def weight(codes):
        return len(codes) + sum(code in web_codes for code in codes)

    limit = sum(weight(unit["codes"]) for unit in units) / nights
    split = []
    for unit in units:
        codes = unit["codes"]
        parts = max(1, round(weight(codes) / limit))
        size = len(codes) // parts + 1
        for start in range(0, len(codes), size):
            split.append({**unit, "codes": codes[start:start + size]})

    plan = [[] for _ in range(nights)]
    night = 0
    load = 0
    total_left = sum(weight(unit["codes"]) for unit in split)
    for unit in split:
        unit_weight = weight(unit["codes"])
        target = total_left / (nights - night) if night < nights else total_left
        if plan[night] and load + unit_weight / 2 > target and night < nights - 1:
            total_left -= load
            night += 1
            load = 0
        plan[night].append({**unit, "webCodes": [code for code in unit["codes"] if code in web_codes]})
        load += unit_weight

    with open("SpotMaster/lists/nightly_plan.json", "w", encoding="utf-8") as file:
        json.dump([{"night": index + 1, "units": units} for index, units in enumerate(plan)], file, ensure_ascii=False, indent=1)
    for index, units in enumerate(plan):
        count = sum(len(unit["codes"]) for unit in units)
        web = sum(len(unit["webCodes"]) for unit in units)
        print(index + 1, "、".join(unit["name"] for unit in units), f"{count}市区町村 検索{web}回")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 13)
