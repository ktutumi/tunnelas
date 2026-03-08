# Tunnelas Rebuild Plan

## 目的

- `docs/rebuild_requirements.md` に基づき、`Tunnelas` を macOS メニューバーアプリとして再構築する。
- XcodeGen ベースの開発基盤、設定読み込み、ランタイム制御、ログ参照、基本 UI を初期実装する。

## 完了条件

- `project.yml` から Xcode プロジェクトを再生成できる。
- `~/.config/tunnelas/config.json` を読み込み、バリデーションできる。
- SSH と Kubernetes のルールをメニューバーから起動・停止できる。
- 直近ログとエラー概要をログウィンドウで確認できる。
- コアロジックを自動テストで検証できる。

## 実装フェーズ

1. タスク管理と設計記録を整備する。
2. XcodeGen、ターゲット構成、基本エントリポイントを作る。
3. 設定モデル、バリデータ、設定リポジトリを実装する。
4. ランタイム状態管理、プロセス実行、ログ記録を実装する。
5. メニューバー UI、ログウィンドウ、設定ウィンドウを実装する。
6. テスト、ビルド、XcodeGen 再生成を検証する。

## GitHub Issue 対応表

1. Tunnelas 基盤構築と XcodeGen プロジェクト作成
2. Tunnelas 設定モデルと config.json 検証実装
3. Tunnelas ランタイム状態管理と外部プロセス実行基盤
4. Tunnelas メニューバー UI とログウィンドウ実装
5. Tunnelas スリープ復帰・終了処理・検証整備

## テスト方針

- 設定デコードとバリデーションの正常系・異常系を `TunnelasCoreTests` で検証する。
- ランタイム状態遷移をスタブ化したプロセスランナーで検証する。
- `xcodegen generate`、`xcodebuild test` を通して、開発基盤と自動テストの成立を確認する。

