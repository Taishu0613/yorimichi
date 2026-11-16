#!/usr/bin/env python3
"""次に作るバッチを表示する。

使い方(リポジトリ直下で): python3 Trivia/scripts/next_batch.py [バッチ番号]
番号を省くと、Trivia/out/bNN.json がまだ無い(または足りない)一番小さいバッチを選ぶ。
各市区町村について、コード・都道府県・名前・WikipediaのURL・今の文(材料)を出す。
"""
import csv
import json
import os
import sys
import urllib.parse

MASTER = "LocalGovernmentCodeJapan_Knowledge.csv"
PLAN = "Trivia/plan.json"
OUT = "Trivia/out"


def written_codes(batch):
    path = os.path.join(OUT, f"b{batch:02d}.json")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as file:
        return set(json.load(file))


def main():
    with open(PLAN, encoding="utf-8") as file:
        plan = json.load(file)
    if len(sys.argv) > 1:
        target = next(entry for entry in plan if entry["batch"] == int(sys.argv[1]))
    else:
        target = next((entry for entry in plan if set(entry["codes"]) - written_codes(entry["batch"])), None)
        if target is None:
            print("全バッチ完了")
            return
    done = written_codes(target["batch"])
    rest = [code for code in target["codes"] if code not in done]
    with open(MASTER, encoding="utf-8-sig", newline="") as file:
        rows = {row[0]: row for row in csv.reader(file)}
    print(f"バッチ {target['batch']}: 残り {len(rest)} / {len(target['codes'])} 市区町村 → Trivia/out/b{target['batch']:02d}.json")
    for code in rest:
        row = rows[code]
        title = row[2]
        # 政令市の区は「横浜市中区」の形でそのまま記事名になる。同名の市町村は記事名が「府中市 (東京都)」のようになるので、開けなければ都道府県名を付けて探す。
        url = "https://ja.wikipedia.org/wiki/" + urllib.parse.quote(title)
        print(f"\n## {code} {row[1]} {row[2]}\n{url}\n[今の都市伝説] {row[7] or '(空)'}\n[今のみどころ] {row[8] or '(空)'}")


if __name__ == "__main__":
    main()
