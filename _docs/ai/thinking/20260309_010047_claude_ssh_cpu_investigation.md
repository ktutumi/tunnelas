# SSH トンネル高 CPU 調査

- 症状: アプリ起動後、SSH トンネルを 1 本起動するごとに CPU 使用率が約 100% 増える。
- 調査対象: `TunnelasCore/TunnelRuntimeStore.swift` と `TunnelasInfra/SystemProcessRunner.swift`。
- 結論: 根本原因は `SystemProcessRunner` の `Pipe.fileHandleForReading.readabilityHandler`。
- 理由: stdout / stderr の `availableData` が 0 バイトでも継続的に callback されるため、出力がない長寿命プロセスで busy loop になる。
- 補助検証: `Process` で `/bin/sleep 1` を起動し stdout/stderr に `Pipe` を接続したところ、約 1.2 秒で stdout 131107 回、stderr 131685 回 callback が発生した。
- 推定影響: `ssh -N` のような通常ほぼ無出力の常駐プロセスで、トンネル 1 本ごとに 2 本の pipe 監視が常時スピンし、CPU 使用率が線形に増える。
- 補足: `TunnelRuntimeStore` 側の `waitForTermination` ポーリングは停止時のみ実行されるため、常時高 CPU の主因ではない。
