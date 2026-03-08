# Plan: メニューバー項目のコンパクト化と詳細のサブメニュー化

## Issue

- #7

## 目的

- メニューバークリック時の初期表示をコンパクトにし、詳細情報を階層サブメニューへ移す。
- macOS の標準メニュー体験に寄せ、主要操作への到達を速くする。

## 対象ファイル

- `TunnelasApp/TunnelasApp.swift`
- `TunnelasApp/MenuBarContentView.swift`
- `TunnelasApp/AppModel.swift`
- `TunnelasCoreTests/TunnelRuntimeStoreTests.swift`

## 実装手順

1. `MenuBarExtra` をネイティブメニュー中心の構成へ切り替える。
2. 最上位に全体ステータス、グループ単位の要約、主要操作を配置する。
3. グループとルールの詳細をサブメニューへ移し、状態依存の操作に整理する。
4. 集計ロジックと表示補助を `AppModel` に追加する。
5. テストとビルドで回帰を確認する。

## 検証観点

- [ ] 最上位メニューが長大なスクロール UI になっていない
- [ ] グループとルールの詳細にサブメニューから到達できる
- [ ] Settings と Quit にショートカットが表示される
- [ ] `xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` が通る

## 影響範囲

- メニューバー UI の体験が変わるが、設定モデルやランタイム制御のデータ構造は変更しない。

## リスク

- SwiftUI のメニュー表現で読み取り専用情報行の見せ方に制約がある。
- `MenuBarExtra` のスタイル変更でレイアウトとアクセシビリティの確認が必要。
