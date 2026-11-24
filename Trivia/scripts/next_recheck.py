#!/usr/bin/env python3
"""全バッチのあとに、都市伝説を調べ直す市区町村を48件ずつ出す。

使い方(リポジトリ直下で): python3 Trivia/scripts/next_recheck.py
対象は Trivia/legend_recheck.json のコード。「ありません」の定型文になっている街を先に、
出典が弱い街をあとに並べ、まだ Trivia/out/cNN.json に入っていないものから48件を出す。
結果は Trivia/out/cNN.json に {"コード": {"highlight": 今のみどころ, "legend": 新しい都市伝説}} の形で書く。
merge_trivia.py はファイル名順に読むので、cNN.json の文が bNN.json の文より優先される。
"""
import csv
import glob
import json

SIZE = 48
NONE_SUFFIX = "特に有名な怪談・都市伝説はありません。"


def load(pattern):
    entries = {}
    for path in sorted(glob.glob(pattern)):
        with open(path, encoding="utf-8") as file:
            entries.update(json.load(file))
    return entries


def main():
    with open("Trivia/legend_recheck.json", encoding="utf-8") as file:
        codes = json.load(file)
    written = load("Trivia/out/b*.json")
    done = load("Trivia/out/c*.json")
    rest = [code for code in codes if code not in done and code in written]
    rest.sort(key=lambda code: (not written[code]["legend"].endswith(NONE_SUFFIX), code))
    if not rest:
        print("調べ直し完了")
        return
    number = len(glob.glob("Trivia/out/c*.json")) + 1
    target = rest[:SIZE]
    with open("LocalGovernmentCodeJapan_Knowledge.csv", encoding="utf-8-sig", newline="") as file:
        rows = {row[0]: row for row in csv.reader(file)}
    print(f"調べ直し {number}: {len(target)}件(残り {len(rest)}件) → Trivia/out/c{number:02d}.json")
    for code in target:
        entry = written[code]
        print(f"\n## {code} {rows[code][1]} {rows[code][2]}")
        print(f"[今の都市伝説] {entry['legend']}")
        print(f"[今のみどころ] {entry['highlight']}")


if __name__ == "__main__":
    main()
