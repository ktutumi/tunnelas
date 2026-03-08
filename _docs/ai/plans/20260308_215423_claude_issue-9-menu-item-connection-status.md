# Plan: メニュー項目への接続ステータス表示追加

## Issue

- #9

## 目的

- メニューバーのグループ項目とルール項目を一覧した時点で接続状態を把握できるようにする。
- `running` / `starting` / `error` / `stopped` の 4 状態を記号で識別できるようにする。

## 対象ファイル

- `TunnelasCore/RuntimeTypes.swift`
- `TunnelasApp/MenuBarContentView.swift`
- `TunnelasCoreTests/TunnelRuntimeStoreTests.swift`
- `tasks/todo.md`

## 実装手順

1. `RuleSnapshot` と `GroupSnapshot` にメニュー項目用の状態シンボルとアクセシビリティ用ラベルを追加する。
2. メニューのグループ項目とルール項目が新しい状態シンボルを使うように更新する。
3. 状態集約と表示責務をテストで固定し、`xcodebuild test` で回帰確認する。

## 検証観点

- [ ] ルールの 4 状態に対して期待するシンボルが返る
- [ ] グループの集約状態が `error > starting > running > stopped` で判定される
- [ ] メニュー描画側が新しい状態シンボルを利用する
- [ ] `xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` が通る

## 影響範囲

- 変更はメニューバー UI の表示とその表示補助ロジックに限定する。

## リスク

- 記号のみの表現は意味が曖昧になりやすいため、アクセシビリティラベルで状態文言を補完する。
