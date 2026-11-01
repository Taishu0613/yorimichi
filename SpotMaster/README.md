# みどころマスタ

市区町村シートの「この街でできること」に出すみどころのマスタです。AIがさまざまな情報源から総合評価した結果を、市区町村ごとに最大10件まとめます。アプリは同梱のCSVを読むだけで、アプリの中でAIも検索も動きません。

ファイル: `WAGhack/WAGhack/Resources/MunicipalitySpots.csv`（UTF-8・BOMなし・1行目は見出し）

| 列 | 内容 |
|---|---|
| `code` | 行政区域コード5桁。`LocalGovernmentCodeJapan_Knowledge.csv` のコードと同じ。政令指定都市は区のコードで書く（市のコードの行が無ければ、市の画面では区の行を順位の順に混ぜて出す） |
| `rank` | 市区町村の中の順位。1からの連番、最大10 |
| `name` | 施設・場所の名前。Appleマップ・Googleマップでそのまま検索するので、地図に載っている表記にする |
| `category` | `shrine` `temple` `castle` `history` `museum` `art` `garden` `view` `waterfront` `nature` `animals` `hotSpring` `park` `town` `food` `entertainment` `landmark` `other` のどれか（アイコンと、`action` が空のときの言葉を決める） |
| `action` | 何をするかの短い言葉（16字まで）。例: 港の景色を眺める。空でもよい |
| `reason` | おすすめの理由の一文（40字まで）。空でもよい |

## 入れないもの

- 座標。スポットはマップアプリで「名前＋市区町村名」を検索して開くので要らない（AIが作った座標のずれも避けられる）。
- MapKit・Googleの検索結果そのもの。Appleの規約で地図データの保存は一時的なものに限られ、Google Placesも場所IDを除き保存を禁じている。参考に見るのは構わないが、結果をそのまま書き写さない。
- 営業時間・料金・混雑など変わりやすい情報。閉業・閉園した場所。

## 作るときの指示（AIに渡す文）

```text
日本の市区町村「{都道府県}{市区町村}」（行政区域コード {code}）について、旅行者が寄り道する価値のある場所を最大10件、おすすめの順に選んでください。
- 公的な観光情報、Wikipedia、旅行ガイドなど複数の情報源を照らし合わせ、一般的に有名な場所を優先する。定番だけでなく、街の個性が分かる通りや商店街、新しい人気施設も入れる。
- 必ずその市区町村の中にあり、現在営業・公開している場所だけにする。実在を確認できない場所は入れない。良い候補が少なければ10件未満でよい。
- 同じ種類が並びすぎないようにする。同じ施設の部分（門や櫓など）を別々に数えない。
- 名前は地図に載っている表記にする。
次のCSV形式だけを出力してください（見出しなし）: code,rank,name,category,action,reason
categoryは次から選ぶ: shrine temple castle history museum art garden view waterfront nature animals hotSpring park town food entertainment landmark other
actionは「〜する」で終わる16字以内の言葉、reasonは40字以内の一文。文章は自分の言葉で書き、情報源の文を写さない。
```

## 確かめ方

`SpotMaster/scripts/check_spots.swift` が、形式の間違いと、名前で検索してその市区町村の境界の中に見つからない行を挙げます。使い方はファイルの先頭にあります。検索の回数制限のため1件ごとに間を置くので、全国分は半日ほどかかります（`--format-only` なら形式だけをすぐ確かめられます）。

「要確認」は実在しないとは限りません（地図の表記が違うだけのことが多い）。名前を地図の表記に直すか、確かめられないものは別の場所に差し替えます。
