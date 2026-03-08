# PR #6 Second Review Fixes

- shutdown が無期限待ちでアプリ終了を止めないよう、停止待ちに timeout を追加する。
- config 再読み込み時に newly-enabled rule が初回起動時と同様に自動起動するようにする。
- review 指摘を regression test で固定し、再レビュー時に同じ論点が戻らないようにする。
