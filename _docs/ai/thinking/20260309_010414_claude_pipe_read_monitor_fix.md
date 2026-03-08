# PipeReadMonitor への置き換え

- 背景: `Pipe.fileHandleForReading.readabilityHandler` が 0 バイト `availableData` でも連続発火し、無出力プロセスで CPU を消費する。
- 方針: `SystemProcessRunner` の監視を `DispatchSourceRead` ベースに置き換える。
- 理由: 読み取り可能イベントが来たときだけ `read(upToCount:)` を実行でき、アイドル状態の pipe で busy loop しない。
- 実装: `TunnelasInfra/SystemProcessRunner.swift` に内部 `PipeReadMonitor` を追加し、stdout/stderr を同一方式で監視する。
- テスト: `TunnelasCoreTests/SystemProcessRunnerTests.swift` で、(1) writer が開いたまま無出力の pipe ではイベントが発火しないこと、(2) 書き込み後に writer を閉じるとデータ取得と EOF 完了が起きること、を確認した。
