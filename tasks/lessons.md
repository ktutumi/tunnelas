# Lessons

## 2026-03-08

- GitHub 連携では `gh` CLI と GitHub MCP を同一視しない。読み取り可否と書き込み可否、認証経路、権限は別々に確認する。
- ユーザーから「MCP が使えるはず」と修正を受けたら、推測で説明を続けず `get_me` などの最小 API で即座に疎通確認する。
- `gh auth status` が sandbox 内で失敗しても、sandbox 外の `gh` は通る場合がある。Issue/PR 作成を止める前に昇格実行の可能性を確認する。
