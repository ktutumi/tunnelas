# Tunnelas Todo

## Overview

- [x] XcodeGen ベースの macOS メニューバーアプリ基盤を作成する
- [x] 設定読み込みとバリデーションを実装する
- [x] SSH / Kubernetes のランタイム制御を実装する
- [x] メニューバー UI とログウィンドウを実装する
- [x] スリープ復帰、終了処理、テストを整備する

## Issue Links

1. #1 Tunnelas 基盤構築と XcodeGen プロジェクト作成
2. #2 Tunnelas 設定モデルと config.json 検証実装
3. #5 Tunnelas ランタイム状態管理と外部プロセス実行基盤
4. #4 Tunnelas メニューバー UI とログウィンドウ実装
5. #3 Tunnelas スリープ復帰・終了処理・検証整備
6. #7 メニューバー項目のコンパクト化と詳細のサブメニュー化
7. #9 メニュー項目への接続ステータス表示追加

## Checklist

- [x] `project.yml` を作成し、`xcodegen generate` が通る
- [x] `TunnelasApp` / `TunnelasCore` / `TunnelasInfra` / `TunnelasCoreTests` を作成する
- [x] `config.json` の互換モデルとバリデーションを実装する
- [x] 設定再読み込み失敗時に直前の有効設定を維持する
- [x] SSH ルールを起動・停止できる
- [x] Kubernetes ルールを起動・停止できる
- [x] グループ単位の一括起動・停止ができる
- [x] ルール単位の状態、エラー、直近ログを表示できる
- [x] スリープ復帰時の再接続ができる
- [x] アプリ終了時に管理プロセスを停止できる
- [x] `xcodebuild test` が通る

## Current Task

### Issue #9 メニュー項目への接続ステータス表示追加

- [x] グループ項目に接続状態を示す記号を表示する
- [x] ルール項目に接続状態を示す記号を表示する
- [x] `running` / `starting` / `error` / `stopped` の 4 状態を識別できるようにする
- [x] `xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を通す

## Review Notes

- 2026-03-08 16:16 JST に `xcodegen generate` を実行し、`Tunnelas.xcodeproj` を生成した。
- 2026-03-08 16:16 JST に `xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を実行し、7 テストが成功した。
- 2026-03-08 16:41 JST に GitHub Issue #1 から #5 を作成し、タスク分割を GitHub 側へ反映した。
- GitHub MCP は読み取りできたが Issue 作成は 403 だった。Issue 作成は sandbox 外の `gh issue create` で実行した。
- GitHub MCP は Issue 更新も 403 だったため、#3 と #4 の依存関係修正は sandbox 外の `gh issue edit` で実行した。
- 2026-03-08 18:44 JST に PR #6 の review 指摘を反映し、`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 10 テストが成功した。
- 2026-03-08 19:50 JST に PR #6 の再 review 指摘を反映し、`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 12 テストが成功した。
- 2026-03-08 20:08 JST に PR #6 の追加 review 指摘を反映し、起動時の enabled rule 二重起動を防ぐ修正を入れた。`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 13 テストが成功した。
- 2026-03-08 21:05 JST に GitHub Issue #7 を作成し、メニューバー UI のコンパクト化とサブメニュー化に着手した。
- 2026-03-08 21:07 JST にブランチ名を `feature/menu-bar-compact-submenu` へ修正し、GitHub 向けの lowercase / kebab-case 運用を `AGENTS.md` に明文化した。
- 2026-03-08 21:10 JST に `xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を実行し、16 テストが成功した。
- 2026-03-08 21:54 JST に GitHub Issue #9 を作成し、メニュー項目への接続ステータス表示追加に着手した。
- 2026-03-08 21:55 JST にメニューのグループ項目とルール項目へ状態記号とアクセシビリティラベルを追加し、`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 17 テストが成功した。
