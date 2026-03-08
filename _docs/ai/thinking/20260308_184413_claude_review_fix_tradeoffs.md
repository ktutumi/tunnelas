# Review Fix Tradeoffs

- 停止完了待ちは `TunnelRuntimeStore` に集約した。`restart` と `shutdown` の両方が同じ待機経路を使えるため、責務の重複を避けられる。
- `willTerminate` では MainActor に依存しない static helper から `Task.detached + DispatchSemaphore` を使って shutdown 完了を待つ。MainActor 継承 Task だと終了直前にデッドロックし得るため避けた。
- `stopRule` 自体は非同期 fire-and-forget のまま残した。通常 UI 操作は即時 return を維持しつつ、厳密に待つ必要がある経路だけを `stopRuleAndWait` に分離した。
