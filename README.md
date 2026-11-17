# Tabby

macOS で、複数のブラウザで開いているタブをまとめて検索し、選んだタブへすぐ切り替えるためのメニューバーアプリです。

ホットキー（デフォルトは `⇧⌘Space`）を押すと検索パネルが開き、起動中のブラウザすべてのタブがタイトルと URL で絞り込めます。

## 機能

- 起動中の対応ブラウザ全部のタブを横断検索（タイトル、URL、ブラウザ名）
- スペース区切りで複数キーワードの AND 検索。部分一致に加えてあいまい一致（`gthb` → GitHub）にも対応。全角/半角や大文字/小文字は区別しません
- 選んだタブをアクティブにし、そのウィンドウを最前面に（最小化されていれば元に戻します）
- パネルからタブを閉じる
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

ブラウザを追加したい場合は `Sources/Tabby/Browser.swift` の `Browser.all` に bundle ID を追加してください（Chrome 互換の AppleScript 辞書を持つブラウザなら `kind: .chromium` で動くはずです）。

## キー操作

| キー | 動作 |
| --- | --- |
| `⇧⌘Space` | パネルを開く / 閉じる |
| `↑` `↓`（`⌃P` `⌃N`、`⌃K` `⌃J`） | 選択を移動 |
| `⌘↑` `⌘↓` | 先頭 / 末尾へ |
| `Page Up` `Page Down` | 8 件ずつ移動 |
| `↩` | 選択中のタブを開く |
| `⌘⌫` | 選択中のタブを閉じる |
| `esc` | パネルを閉じる |

日本語入力の変換中は `↩` や矢印キーは IME 側に渡します。クリックでも開けます。

## ビルドとインストール

macOS 13 以降と Swift 5.9 以降（Xcode 15+ もしくは Command Line Tools）が必要です。

```sh
make app       # build/Tabby.app を作成
make run       # ビルドして起動
make install   # /Applications にコピー
```

`UNIVERSAL=1 make app` で arm64 + x86_64 のユニバーサルバイナリになります（Xcode が必要）。

GitHub Actions でもビルドしており、各ワークフロー実行の Artifacts から `Tabby.zip` を取得できます。署名はアドホックなので、ダウンロードしたものは初回のみ Finder で右クリック →「開く」で起動してください。

## 権限について

初めてタブを取得するとき、ブラウザごとに「“Tabby”から“Google Chrome”を制御しようとしています」というダイアログが出るので「許可」を選んでください。

拒否してしまった場合や、パネル下部に `not allowed to control this browser` と表示される場合は「システム設定 > プライバシーとセキュリティ > オートメーション」で Tabby の該当ブラウザをオンにしてください。

アドホック署名のまま再ビルドすると macOS が別アプリとみなし、許可を求められ直すことがあります。気になる場合は手元の署名 ID を指定してビルドしてください。

```sh
CODESIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" make app
```

許可の状態がおかしくなったときは次のコマンドでリセットできます。

```sh
tccutil reset AppleEvents com.github.yteraoka.tabby
```

## ホットキーの変更

```sh
defaults write com.github.yteraoka.tabby hotkey "ctrl+option+t"
```

設定後に Tabby を再起動すると反映されます。修飾キーは `cmd` `shift` `option`（`opt` / `alt`）`ctrl` が使え、キーは英数字、`space`、`return`、`tab`、`f1`〜`f12`、記号（`,` `.` `/` `;` `'` `[` `]` `-` `=` `` ` ``）が指定できます。ほかのアプリと重なって登録できなかった場合は、メニューにショートカットが表示されません。

元に戻すには:

```sh
defaults delete com.github.yteraoka.tabby hotkey
```

## しくみ

- 各ブラウザへの問い合わせは `osascript`（JavaScript for Automation）を子プロセスで実行し、ブラウザごとに並列で取得します（`Sources/Tabby/Scripts.swift`）
- 起動していないブラウザには問い合わせません（問い合わせるとブラウザが起動してしまうため）
- タブの切り替えと削除は AppleScript で行います。Chromium 系と Arc はタブ ID でタブを特定するので、一覧取得後にタブが移動していても正しいタブを開きます。Safari にはタブ ID がないため、位置（インデックス）で特定します

## 既知の制限

- Chrome などで同じブラウザのウィンドウが複数あると、ウィンドウは前面に出てもキーボードフォーカスが前のウィンドウに残ることがあります（ブラウザ側の AppleScript 実装の挙動）
- Arc で別の Space にあるタブが一覧に出るかどうかは Arc の AppleScript 実装に依存します

## ライセンス

MIT
