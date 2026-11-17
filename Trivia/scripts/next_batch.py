#!/usr/bin/env python3
"""次に作るバッチを表示する。

使い方(リポジトリ直下で): python3 Trivia/scripts/next_batch.py [バッチ番号]
番号を省くと、Trivia/out/bNN.json がまだ無い(または足りない)一番小さいバッチを選ぶ。
各市区町村について、コード・都道府県・名前・WikipediaのURL・今の文(材料)を出す。
"""
import csv
import json
import re
import os
import sys
import urllib.parse

MASTER = "LocalGovernmentCodeJapan_Knowledge.csv"
PLAN = "Trivia/plan.json"
OUT = "Trivia/out"
REDO = "Trivia/redo.json"


def written_codes(batch):
    path = os.path.join(OUT, f"b{batch:02d}.json")
    if not os.path.exists(path):
        return set()
    with open(path, encoding="utf-8") as file:
        return set(json.load(file))


def main():
    with open(PLAN, encoding="utf-8") as file:
        plan = json.load(file)
    redo = []
    if os.path.exists(REDO):
        with open(REDO, encoding="utf-8") as file:
            redo = json.load(file)
    if len(sys.argv) > 1:
        target = next(entry for entry in plan if entry["batch"] == int(sys.argv[1]))
    elif redo:
        # 古い調べ方で作ったバッチを作り直す。bNN.json を上書きし、終わったら redo.json から番号を消す。
        target = next(entry for entry in plan if entry["batch"] == redo[0])
        print(f"作り直し: バッチ {target['batch']}(Trivia/out/b{target['batch']:02d}.json を上書きし、終わったら Trivia/redo.json から {target['batch']} を消す)")
    else:
        target = next((entry for entry in plan if set(entry["codes"]) - written_codes(entry["batch"])), None)
        if target is None:
            print("全バッチ完了")
            return
    done = set() if target["batch"] in redo else written_codes(target["batch"])
    rest = [code for code in target["codes"] if code not in done]
    with open(MASTER, encoding="utf-8-sig", newline="") as file:
        rows = {row[0]: row for row in csv.reader(file)}
    print(f"バッチ {target['batch']}: 残り {len(rest)} / {len(target['codes'])} 市区町村 → Trivia/out/b{target['batch']:02d}.json")
    for code in rest:
        row = rows[code]
        title = row[2]
        # 同名の市町村は記事名が「伊達市 (北海道)」のようになる。開けなかった方は捨てる。
        urls = [title]
        ward = re.fullmatch(r"(.+?市)(.+区)", title)
        if ward:
            # 政令市の区の記事名は「中央区 (札幌市)」か「白石区」の形。
            urls = [f"{ward.group(2)}_({ward.group(1)})", ward.group(2)]
        else:
            urls.append(f"{title}_({row[1]})")
        url = " または ".join("https://ja.wikipedia.org/wiki/" + urllib.parse.quote(name) for name in urls)
        print(f"\n## {code} {row[1]} {row[2]}\n{url}\n[今の都市伝説] {row[7] or '(空)'}\n[今のみどころ] {row[8] or '(空)'}")


if __name__ == "__main__":
    main()
