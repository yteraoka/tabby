# Taffy

macOS で、複数のブラウザで開いているタブをまとめて検索し、選んだタブへすぐ切り替えるためのメニューバーアプリです。

ホットキー（デフォルトは `⇧⌘Space`）を押すと検索パネルが開き、起動中のブラウザすべてのタブがタイトルと URL で絞り込めます。

## 機能

- 起動中の対応ブラウザ全部のタブを横断検索（タイトル、URL、ブラウザ名）
- スペース区切りで複数キーワードの AND 検索。部分一致に加えてあいまい一致（`gthb` → GitHub）にも対応。全角/半角や大文字/小文字は区別しません
- 選んだタブをアクティブにし、そのウィンドウを最前面に（最小化されていれば元に戻します）
- パネルからタブを閉じる
- 音声を再生中・カメラ / マイク / 画面共有を使用中のタブにアイコンを表示し、一覧の先頭に並べる（[後述](#音声やカメラを使っているタブ)）
- 前回取得したタブを先に表示し、各ブラウザの結果が届き次第更新します
- ログイン時に起動（メニューバーのメニューから設定）

## 対応ブラウザ

| ブラウザ | 備考 |
| --- | --- |
| Safari / Safari Technology Preview | |
| Google Chrome（Beta / Dev / Canary を含む）/ Chromium | |
| Brave（Beta を含む） | |
| Microsoft Edge（Beta / Dev を含む） | |
| Vivaldi | |
| Arc | |

Firefox は AppleScript でタブ一覧を取得する手段がないため非対応です。Opera も AppleScript のタブ操作がほとんど使えないため対象外にしています。

ブラウザを追加したい場合は `Sources/Taffy/Browser.swift` の `Browser.all` に bundle ID を追加してください（Chrome 互換の AppleScript 辞書を持つブラウザなら `kind: .chromium` で動くはずです）。

## キー操作

| キー | 動作 |
| --- | --- |
| `⇧⌘Space` | パネルを開く / 閉じる |
| `↑` `↓`（`⌃P` `⌃N`、`⌃K` `⌃J`） | 選択を移動 |
| `⌘↑` `⌘↓` | 先頭 / 末尾へ |
| `Page Up` `Page Down` | 8 件ずつ移動 |
| `↩` | 選択中のタブを開く |
| `⌘M` | 音声 / カメラ / マイク / 画面共有を使っているタブだけを表示（もう一度押すと解除） |
| `⌘⌫` | 選択中のタブを閉じる |
| `esc` | パネルを閉じる |

日本語入力の変換中は `↩` や矢印キーは IME 側に渡します。クリックでも開けます。

## 音声やカメラを使っているタブ

音声を再生しているタブや、カメラ・マイク・画面共有を使っているタブ（Web 会議など）には、一覧の右側にアイコンが付きます。

| アイコン | 状態 |
| --- | --- |
| 赤のビデオ | カメラを使用中 |
| オレンジのマイク | マイクを使用中 |
| 紫の画面 | 画面を共有中 |
| 青のスピーカー | 音声を再生中 |
| 灰色の消音スピーカー | ミュート中 |

- 検索語が空のときは、カメラ / マイク / 画面共有のタブ、音声再生中のタブ、ミュート中のタブの順で先頭に並びます
- パネル下部の「N with audio/camera」をクリックするか `⌘M` で、それらのタブだけに絞り込めます
- 検索欄に `@media`（すべて）、`@camera`、`@mic`、`@screen`、`@audio`、`@muted` と入れても絞り込めます。`@cam` のように前方一致でもよく、ほかの語と組み合わせられます（例: `@audio youtube`）

### 有効にする

ブラウザは AppleScript ではこの状態を教えてくれないため、タブバーの各タブをアクセシビリティ API で読んでいます（Chrome 系はタブの読み上げ名に「- Audio playing」「- Camera recording」などを付け、Safari は音声を出しているタブにミュートボタンを出します）。そのため「アクセシビリティ」の許可が必要です。

パネル下部の「Enable audio/camera indicators…」か、メニューバーの「Audio & Camera Indicators…」を選ぶと、システム設定のアクセシビリティの画面が開くので、Taffy をオンにしてください。許可しなくても、タブの検索と切り替えはこれまでどおり使えます。

### 制限

- 英語と日本語のブラウザ表示で判定しています。ほかの言語では判定できないことがあります
- タブバーが見えていないウィンドウ（Safari でタブが 1 つだけのウィンドウなど）や、別の操作スペースにあるウィンドウのタブは判定できません
- Arc はタブがサイドバーにあるため、今のところ判定できません
- アイコンが出ないときは `defaults write com.github.yteraoka.taffy mediaDebug -bool true` を設定して Taffy を再起動すると、読み取ったタブの情報が Console.app（`Taffy media` で検索）に出ます

## インストール

Homebrew の tap（[`yteraoka/homebrew-cask`](https://github.com/yteraoka/homebrew-cask) の `Casks/taffy.rb`）で配布しています。

```sh
brew install --cask yteraoka/cask/taffy
```

- ビルド済みのユニバーサル版（Apple Silicon / Intel、macOS 13 以降）を GitHub Releases から `/Applications/Taffy.app` に入れます
- アプリは ad-hoc 署名で公証していないため、cask のインストール時に quarantine 属性を外しています

アンインストールは `brew uninstall --cask yteraoka/cask/taffy`（設定も消すなら `--zap`）です。

## ソースからのビルド

macOS 13 以降と Swift 5.9 以降（Xcode 15+ もしくは Command Line Tools）が必要です。

```sh
make app       # build/Taffy.app を作成
make run       # ビルドして起動
make install   # /Applications にコピー
```

`UNIVERSAL=1 make app` で arm64 + x86_64 のユニバーサルバイナリになります（Xcode が必要）。

テストは `swift test`（または `make test`）で実行できます。

## CI

`.github/workflows/ci.yaml` が PR の作成・更新時と main への push で動き、次の 2 つのジョブを実行します。

| ジョブ | 内容 |
| --- | --- |
| `test` | `swift test`（検索のスコア、`@` フィルタ、音声 / カメラ状態の判定、ホットキーの解析、AppleScript の生成とコンパイル） |
| `build` | リリースと同じ手順でユニバーサルな `.app` の zip を作り、cask の構文を確認して、zip を Artifacts に上げる |

Actions タブから手動で実行することもできます。

## リリースの流れ

1. main に PR をマージすると、tagpr（`.github/workflows/tagpr.yaml`）がリリース用の PR を作ります。`Sources/Taffy/Version.swift` のバージョンもこの PR で更新されます（`minor` / `major` ラベルで上げ幅を変えられます）
2. リリース用の PR をマージすると、tagpr が `vX.Y.Z` のタグと GitHub Release を作ります
3. タグの push で `.github/workflows/release.yaml`（macOS の runner）が動きます
   1. `scripts/release.sh` で ad-hoc 署名した `Taffy-X.Y.Z-macos-universal.zip` を作り、Release に添付する
   2. `scripts/cask.sh` で `packaging/taffy.rb` の version と sha256 を書き換え、tap の `Casks/taffy.rb` を更新する
4. タグでのリリース時も、zip を作る前に `swift test` を実行します

必要な設定（taffy リポジトリの Settings > Secrets and variables > Actions）:

| 種類 | 名前 | 内容 |
| --- | --- | --- |
| 変数 | `TAGPR_APP_ID` | tagpr 用の GitHub App の Client ID |
| シークレット | `TAGPR_APP_PRIVATE_KEY` | 同じ App の秘密鍵 |
| 変数 | `HOMEBREW_APP_ID` | Release の作成と tap の更新に使う GitHub App の Client ID（Contents: Read and write） |
| シークレット | `HOMEBREW_APP_PRIVATE_KEY` | 同じ App の秘密鍵 |

どちらの App も taffy にインストールし、`HOMEBREW_APP_ID` の App は `homebrew-cask` にもインストールしておきます。

手元でリリース用の zip を作るときは `make release` を実行し、表示された `scripts/cask.sh <version> <sha256>` で tap に置く cask を出力できます。

## 権限について

初めてタブを取得するとき、ブラウザごとに「“Taffy”から“Google Chrome”を制御しようとしています」というダイアログが出るので「許可」を選んでください。

拒否してしまった場合や、パネル下部に `not allowed to control this browser` と表示される場合は「システム設定 > プライバシーとセキュリティ > オートメーション」で Taffy の該当ブラウザをオンにしてください。

アドホック署名のため、Homebrew でのアップグレードや再ビルドのたびに macOS が別アプリとみなし、許可を求められ直すことがあります。気になる場合は手元の署名 ID を指定してビルドしてください。

```sh
CODESIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" make app
```

許可の状態がおかしくなったときは次のコマンドでリセットできます。

```sh
tccutil reset AppleEvents com.github.yteraoka.taffy
```

## ホットキーの変更

```sh
defaults write com.github.yteraoka.taffy hotkey "ctrl+option+t"
```

設定後に Taffy を再起動すると反映されます。修飾キーは `cmd` `shift` `option`（`opt` / `alt`）`ctrl` が使え、キーは英数字、`space`、`return`、`tab`、`f1`〜`f12`、記号（`,` `.` `/` `;` `'` `[` `]` `-` `=` `` ` ``）が指定できます。ほかのアプリと重なって登録できなかった場合は、メニューにショートカットが表示されません。

元に戻すには:

```sh
defaults delete com.github.yteraoka.taffy hotkey
```

## しくみ

- 各ブラウザへの問い合わせは `osascript`（JavaScript for Automation）を子プロセスで実行し、ブラウザごとに並列で取得します（`Sources/Taffy/Scripts.swift`）
- 起動していないブラウザには問い合わせません（問い合わせるとブラウザが起動してしまうため）
- タブの切り替えと削除は AppleScript で行います。Chromium 系と Arc はタブ ID でタブを特定するので、一覧取得後にタブが移動していても正しいタブを開きます。Safari にはタブ ID がないため、位置（インデックス）で特定します

## 既知の制限

- Chrome などで同じブラウザのウィンドウが複数あると、ウィンドウは前面に出てもキーボードフォーカスが前のウィンドウに残ることがあります（ブラウザ側の AppleScript 実装の挙動）
- Arc で別の Space にあるタブが一覧に出るかどうかは Arc の AppleScript 実装に依存します

## ライセンス

MIT
