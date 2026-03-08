# Shutdown Timeout Notes

- timeout 対応は `shutdown()` のみに限定した。再起動や通常停止まで同じ timeout を入れると、旧プロセスが生きたまま再接続を始める危険がある。
- newly-enabled rule の自動起動は `AppModel.reloadConfiguration()` ではなく `TunnelRuntimeStore.applyConfiguration()` に寄せた。初回読み込みと再読み込みの差を UI 層で持たないほうが挙動を揃えやすい。
