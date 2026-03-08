# Runtime Design Notes

- 状態管理は `actor` に集約し、UI から直接プロセスを触らない。
- `ProcessRunner` と `CommandBuilder` を分離して、`ssh` / `kubectl` 実行を差し替え可能にする。
- ログはファイル出力とメモリ保持を併用し、UI はリングバッファを参照する。
- 設定再読み込み失敗時は新設定を適用せず、既存ランタイムを維持する。

