#!/usr/bin/env python3
"""ネット記事を読む市区町村のリストを作る。みどころの評価で、この市区町村だけ観光記事も材料にする。

使い方(リポジトリ直下で): python3 SpotMaster/scripts/article_targets.py
出力: SpotMaster/lists/article_targets.json(コードの一覧)と article_targets.md(確認用)

都市部はルールで決まる(東京23区、政令指定都市とその区、県庁所在地、中核市)。
観光地は有名度の数字では選べない(Wikidataの値は軽井沢町が3、日光市が34)ので、下の TOURIST に手で書く。
"""
import collections
import csv
import json

DESIGNATED_CITIES = set("""札幌市 仙台市 さいたま市 千葉市 横浜市 川崎市 相模原市 新潟市 静岡市 浜松市 名古屋市
京都市 大阪市 堺市 神戸市 岡山市 広島市 北九州市 福岡市 熊本市""".split())
CAPITALS = set("""北海道札幌市 青森県青森市 岩手県盛岡市 宮城県仙台市 秋田県秋田市 山形県山形市 福島県福島市 茨城県水戸市
栃木県宇都宮市 群馬県前橋市 埼玉県さいたま市 千葉県千葉市 神奈川県横浜市 新潟県新潟市 富山県富山市 石川県金沢市
福井県福井市 山梨県甲府市 長野県長野市 岐阜県岐阜市 静岡県静岡市 愛知県名古屋市 三重県津市 滋賀県大津市 京都府京都市
大阪府大阪市 兵庫県神戸市 奈良県奈良市 和歌山県和歌山市 鳥取県鳥取市 島根県松江市 岡山県岡山市 広島県広島市
山口県山口市 徳島県徳島市 香川県高松市 愛媛県松山市 高知県高知市 福岡県福岡市 佐賀県佐賀市 長崎県長崎市 熊本県熊本市
大分県大分市 宮崎県宮崎市 鹿児島県鹿児島市 沖縄県那覇市""".split())
CORE_CITIES = {
    "北海道": "函館市 旭川市", "青森県": "八戸市", "福島県": "郡山市 いわき市", "群馬県": "高崎市 伊勢崎市",
    "埼玉県": "川越市 川口市 越谷市", "千葉県": "船橋市 柏市", "東京都": "八王子市", "神奈川県": "横須賀市",
    "長野県": "松本市", "愛知県": "豊橋市 岡崎市 一宮市 豊田市", "三重県": "四日市市",
    "大阪府": "豊中市 吹田市 高槻市 枚方市 八尾市 寝屋川市 東大阪市", "兵庫県": "姫路市 尼崎市 明石市 西宮市",
    "岡山県": "倉敷市", "広島県": "呉市 福山市", "山口県": "下関市", "福岡県": "久留米市", "長崎県": "佐世保市",
}
TOURIST = {
    "北海道": "小樽市 富良野市 美瑛町 登別市 洞爺湖町 ニセコ町 倶知安町 斜里町 羅臼町 網走市 釧路市 帯広市 稚内市 利尻富士町 礼文町 松前町",
    "青森県": "弘前市 十和田市 五所川原市 深浦町",
    "岩手県": "平泉町 遠野市 花巻市 宮古市",
    "宮城県": "松島町 石巻市 気仙沼市 蔵王町",
    "秋田県": "仙北市 男鹿市",
    "山形県": "鶴岡市 酒田市 上山市 尾花沢市 米沢市",
    "福島県": "会津若松市 下郷町 猪苗代町 北塩原村 磐梯町",
    "茨城県": "大洗町 ひたちなか市 つくば市 鹿嶋市 潮来市",
    "栃木県": "日光市 那須町 那須塩原市 足利市 益子町",
    "群馬県": "草津町 嬬恋村 みなかみ町 富岡市 渋川市",
    "埼玉県": "秩父市 長瀞町",
    "千葉県": "鴨川市 成田市 香取市 館山市 木更津市 南房総市 富津市 勝浦市 銚子市 鋸南町",
    "東京都": "奥多摩町 大島町 八丈町 小笠原村",
    "神奈川県": "鎌倉市 箱根町 小田原市 藤沢市 湯河原町 三浦市 葉山町 真鶴町",
    "新潟県": "佐渡市 湯沢町 妙高市 村上市",
    "富山県": "立山町 南砺市 黒部市 高岡市 氷見市",
    "石川県": "輪島市 加賀市 七尾市 珠洲市 白山市",
    "福井県": "坂井市 小浜市 敦賀市 永平寺町 大野市 勝山市",
    "山梨県": "富士吉田市 富士河口湖町 山中湖村 北杜市 笛吹市 身延町 忍野村",
    "長野県": "軽井沢町 白馬村 山ノ内町 諏訪市 安曇野市 南木曽町 阿智村 小布施町 飯山市 野沢温泉村 上田市",
    "岐阜県": "高山市 白川村 下呂市 郡上市 飛騨市",
    "静岡県": "熱海市 伊東市 下田市 河津町 伊豆市 西伊豆町 松崎町 御殿場市 富士宮市 掛川市 南伊豆町 東伊豆町",
    "愛知県": "犬山市 常滑市 蒲郡市 南知多町 西尾市",
    "三重県": "伊勢市 鳥羽市 志摩市 熊野市 桑名市 伊賀市",
    "滋賀県": "彦根市 長浜市 近江八幡市 高島市 甲賀市",
    "京都府": "宇治市 舞鶴市 宮津市 伊根町 京丹後市 亀岡市 南丹市",
    "兵庫県": "豊岡市 淡路市 洲本市 南あわじ市 朝来市 赤穂市 宝塚市 新温泉町",
    "奈良県": "吉野町 斑鳩町 明日香村 天理市 橿原市 桜井市 天川村",
    "和歌山県": "白浜町 那智勝浦町 高野町 田辺市 串本町 新宮市",
    "鳥取県": "境港市 倉吉市 三朝町 大山町",
    "島根県": "出雲市 大田市 津和野町 隠岐の島町 海士町",
    "岡山県": "備前市 真庭市 瀬戸内市 高梁市",
    "広島県": "廿日市市 尾道市 竹原市",
    "山口県": "萩市 岩国市 長門市 美祢市",
    "徳島県": "鳴門市 三好市",
    "香川県": "琴平町 小豆島町 土庄町 直島町 観音寺市",
    "愛媛県": "今治市 内子町 大洲市 宇和島市",
    "高知県": "四万十市 室戸市 土佐清水市",
    "福岡県": "太宰府市 柳川市 糸島市 宗像市",
    "佐賀県": "唐津市 嬉野市 有田町 伊万里市 武雄市 鹿島市",
    "長崎県": "雲仙市 島原市 五島市 対馬市 壱岐市 平戸市 南島原市",
    "熊本県": "阿蘇市 天草市 南小国町 人吉市 高森町 上天草市",
    "大分県": "別府市 由布市 日田市 竹田市 九重町 国東市 宇佐市 豊後高田市 臼杵市 杵築市",
    "宮崎県": "高千穂町 日南市",
    "鹿児島県": "屋久島町 指宿市 霧島市 奄美市 南九州市",
    "沖縄県": "石垣市 宮古島市 竹富町 与那国町 名護市 本部町 恩納村 今帰仁村 読谷村 座間味村 渡嘉敷村 北谷町",
}


def main():
    with open("LocalGovernmentCodeJapan_Knowledge.csv", encoding="utf-8-sig", newline="") as file:
        rows = list(csv.reader(file))[1:]
    municipalities = [(row[0], row[1], row[2]) for row in rows if row[5] != "TRUE"]
    codes = {(prefecture, name): code for code, prefecture, name in municipalities}

    urban = {}
    for code, prefecture, name in municipalities:
        is_ward = name.endswith("区") and (prefecture == "東京都" or any(name.startswith(city) for city in DESIGNATED_CITIES))
        if is_ward or name in DESIGNATED_CITIES or prefecture + name in CAPITALS \
                or name in CORE_CITIES.get(prefecture, "").split():
            urban[code] = (prefecture, name)

    missing = []
    tourist = {}
    for prefecture, names in TOURIST.items():
        for name in names.split():
            code = codes.get((prefecture, name))
            if code is None:
                missing.append(prefecture + name)
            elif code not in urban:
                tourist.setdefault(prefecture, []).append((code, name))
    print("マスタに無い名前:", missing)

    tourist_count = sum(map(len, tourist.values()))
    print(f"都市部{len(urban)} 観光地{tourist_count} 合計{len(urban) + tourist_count}/{len(municipalities)}")
    with open("SpotMaster/lists/article_targets.json", "w", encoding="utf-8") as file:
        json.dump({"urban": sorted(urban), "tourist": sorted(code for items in tourist.values() for code, _ in items)},
                  file, ensure_ascii=False, indent=1)

    lines = ["# ネット記事を読む市区町村", "", f"都市部{len(urban)}市区町村と、観光地{tourist_count}市町村です。", "", "## 観光地（AIが選んだ候補）", ""]
    lines += [f"- **{prefecture}**：" + "、".join(name for _, name in items) for prefecture, items in tourist.items()]
    lines += ["", "## 都市部（ルールで決まるもの）", "", "東京23区、政令指定都市とその区、県庁所在地、中核市。区は市に含めて省略しています。", ""]
    cities = collections.defaultdict(list)
    for code, (prefecture, name) in sorted(urban.items()):
        if not name.endswith("区"):
            cities[prefecture].append(name)
    lines += [f"- **{prefecture}**：" + "、".join(names) for prefecture, names in cities.items()]
    with open("SpotMaster/lists/article_targets.md", "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
