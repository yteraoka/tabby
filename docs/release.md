# リリースの流れ

[README](../README.ja.md) | [開発者向け情報](development.md)

1. main に PR をマージすると、tagpr（`.github/workflows/tagpr.yaml`）がリリース用の PR を作ります。`Sources/Taffy/Version.swift` のバージョンもこの PR で更新されます（`minor` / `major` ラベルで上げ幅を変えられます）
2. リリース用の PR をマージすると、tagpr が `vX.Y.Z` のタグと GitHub Release を作ります
3. タグの push で `.github/workflows/release.yaml`（macOS の runner）が動きます
   1. `scripts/release.sh` で ad-hoc 署名した `Taffy-X.Y.Z-macos-universal.zip` を作り、Release に添付する
   2. `scripts/cask.sh` で `packaging/taffy.rb` の version と sha256 を書き換え、tap（[`yteraoka/homebrew-cask`](https://github.com/yteraoka/homebrew-cask)）の `Casks/taffy.rb` を更新する
4. タグでのリリース時も、zip を作る前に `swift test` を実行します

## 必要な設定

taffy リポジトリの Settings > Secrets and variables > Actions:

| 種類 | 名前 | 内容 |
| --- | --- | --- |
| 変数 | `TAGPR_APP_ID` | tagpr 用の GitHub App の Client ID |
| シークレット | `TAGPR_APP_PRIVATE_KEY` | 同じ App の秘密鍵 |
| 変数 | `HOMEBREW_APP_ID` | Release の作成と tap の更新に使う GitHub App の Client ID（Contents: Read and write） |
| シークレット | `HOMEBREW_APP_PRIVATE_KEY` | 同じ App の秘密鍵 |

どちらの App も taffy にインストールし、`HOMEBREW_APP_ID` の App は `homebrew-cask` にもインストールしておきます。

## 手元でのリリース用 zip の作成

`make release` を実行し、表示された `scripts/cask.sh <version> <sha256>` で tap に置く cask を出力できます。
