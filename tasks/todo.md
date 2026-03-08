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

## Review Notes

- 2026-03-08 16:16 JST に `xcodegen generate` を実行し、`Tunnelas.xcodeproj` を生成した。
- 2026-03-08 16:16 JST に `xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を実行し、7 テストが成功した。
- 2026-03-08 16:41 JST に GitHub Issue #1 から #5 を作成し、タスク分割を GitHub 側へ反映した。
- GitHub MCP は読み取りできたが Issue 作成は 403 だった。Issue 作成は sandbox 外の `gh issue create` で実行した。
- GitHub MCP は Issue 更新も 403 だったため、#3 と #4 の依存関係修正は sandbox 外の `gh issue edit` で実行した。
- 2026-03-08 18:44 JST に PR #6 の review 指摘を反映し、`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 10 テストが成功した。
- 2026-03-08 19:50 JST に PR #6 の再 review 指摘を反映し、`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 12 テストが成功した。
- 2026-03-08 20:08 JST に PR #6 の追加 review 指摘を反映し、起動時の enabled rule 二重起動を防ぐ修正を入れた。`xcodebuild test -scheme Tunnelas -project Tunnelas.xcodeproj -destination 'platform=macOS'` を再実行して 13 テストが成功した。
