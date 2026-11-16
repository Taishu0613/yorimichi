#!/usr/bin/env python3
"""Trivia/out/*.json の文を確かめて、市区町村マスタの「豆知識(歴史)」(怪奇・都市伝説)と
「豆知識(有名なもの)」(みどころ)の列へ書き込む。

使い方(リポジトリ直下で): python3 Trivia/scripts/merge_trivia.py [--check]
入力は {"行政区域コード": {"highlight": "みどころの文", "legend": "都市伝説の文"}} の形。
--check を付けると、確かめるだけで書き込まない。問題があれば理由を出して終了コード1で終わる(書き込まない)。
"""
import csv
import glob
import json
import re
import sys

MASTER = "LocalGovernmentCodeJapan_Knowledge.csv"
LEGEND_COLUMN = 7
HIGHLIGHT_COLUMN = 8
BANNED = ["確認できない", "見つからない", "見当たらない", "知られていない", "が定番", "という物語が伝わる", "未確認談"]


def first_sentence(text):
    match = re.search(r"[。！？]", text)
    return text[: match.end()] if match else text


def problems(code, name, entry):
    found = []
    highlight = entry.get("highlight", "")
    legend = entry.get("legend", "")
    if not 100 <= len(highlight) <= 190:
        found.append(f"みどころの長さ {len(highlight)}字(100〜190字)")
    if len(first_sentence(highlight)) > 50:
        found.append(f"みどころの最初の一文が {len(first_sentence(highlight))}字(50字まで)")
    none_text = f"{name}には、特に有名な怪談・都市伝説はありません。"
    if legend != none_text and not 100 <= len(legend) <= 190:
        found.append(f"都市伝説の長さ {len(legend)}字(100〜190字。無いときは「{none_text}」ちょうど)")
    for word in BANNED:
        if word in highlight or (word in legend and legend != none_text):
            found.append(f"使わない言い回し「{word}」")
    return [f"{code} {name}: {problem}" for problem in found]


def main():
    check_only = "--check" in sys.argv
    entries = {}
    for path in sorted(glob.glob("Trivia/out/*.json")):
        with open(path, encoding="utf-8") as file:
            entries.update(json.load(file))

    with open(MASTER, encoding="utf-8-sig", newline="") as file:
        rows = list(csv.reader(file))
    names = {row[0]: row[2] for row in rows[1:]}
    errors = []
    for code, entry in entries.items():
        if code not in names or not names[code]:
            errors.append(f"{code}: マスタに無い市区町村コード")
            continue
        errors += problems(code, names[code], entry)
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    if check_only:
        print(f"{len(entries)}市区町村、問題なし")
        return

    for row in rows[1:]:
        entry = entries.get(row[0])
        if entry:
            row[LEGEND_COLUMN] = entry["legend"]
            row[HIGHLIGHT_COLUMN] = entry["highlight"]
    # 既存のファイルと同じくBOM付き・CRLF・全項目を引用符で囲む形で書く。
    with open(MASTER, "w", encoding="utf-8-sig", newline="") as file:
        csv.writer(file, quoting=csv.QUOTE_ALL, lineterminator="\r\n").writerows(rows)
    print(f"{len(entries)}市区町村に書き込みました")


if __name__ == "__main__":
    main()
