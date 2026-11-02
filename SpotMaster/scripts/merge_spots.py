#!/usr/bin/env python3
"""みどころを市区町村マスタ(LocalGovernmentCodeJapan_Knowledge.csv)の10列目へ書き込む。

使い方(リポジトリ直下で): python3 SpotMaster/scripts/merge_spots.py SpotMaster/work/spots
入力のフォルダの *.json は {"行政区域コード": [{"name","category","action","reason"}, ...]} の形。
書き込むのは「みどころ(JSON)」の列だけで、他の列は変えない。同じコードが複数のファイルにあれば、ファイル名順で後のものを使う。
"""
import csv
import glob
import json
import os
import sys

MASTER = "LocalGovernmentCodeJapan_Knowledge.csv"
HEADER = "みどころ(JSON)"


def main(folder):
    spots = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
        with open(path, encoding="utf-8") as file:
            spots.update(json.load(file))

    with open(MASTER, encoding="utf-8-sig", newline="") as file:
        rows = list(csv.reader(file))
    filled = 0
    for index, row in enumerate(rows):
        base = row[:9]
        if index == 0:
            rows[index] = base + [HEADER]
            continue
        entries = spots.get(row[0])
        text = json.dumps(entries, ensure_ascii=False, separators=(",", ":")) if entries else ""
        filled += bool(entries)
        rows[index] = base + [text]

    # 既存のファイルと同じくBOM付き・CRLF・全項目を引用符で囲む形で書く。
    with open(MASTER, "w", encoding="utf-8-sig", newline="") as file:
        csv.writer(file, quoting=csv.QUOTE_ALL, lineterminator="\r\n").writerows(rows)
    print(f"{filled}市区町村に書き込みました(全{len(rows) - 1}行)")


if __name__ == "__main__":
    main(sys.argv[1])
