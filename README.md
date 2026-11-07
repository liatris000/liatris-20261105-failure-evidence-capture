# capture-on-fail

失敗した試行だけ応答を保存する curl ラッパー。

記事: https://zenn.dev/liatris/articles/20261105-failure-evidence-capture

## 前提

- Bash と curl(curl 8.5.0 と 8.7.1 で確認)
- デモ用のローカルサーバーを動かすなら Python 3(標準ライブラリのみ)

## 動かし方

```bash
EVIDENCE_DIR=evidence MAX_ATTEMPTS=3 ./capture-on-fail.sh URL [curl の追加引数...]
```

- 成功した試行は何も残さず、応答の本文だけを標準出力に出して終了コード 0
- 失敗した試行だけ、`evidence/<UTC日時>-<PID>/attempt-N/` に応答ヘッダ・本文・ステータス・所要時間を保存する。最後まで失敗したら終了コード 1
- `Authorization` / `Cookie` / `X-Api-Key` の値は、保存する前に `[REDACTED]` に置き換える

### ローカルで失敗を再現する

```bash
git clone https://github.com/liatris000/liatris-20261105-failure-evidence-capture.git
cd liatris-20261105-failure-evidence-capture
python3 demo/server.py &    # 127.0.0.1:8765 で起動。/flaky は 503、それ以外は 200 を返す

./capture-on-fail.sh http://127.0.0.1:8765/ok
./capture-on-fail.sh http://127.0.0.1:8765/flaky -H "Authorization: Bearer secret-token"
```

## 期待される出力

`/ok`:

```text
{"ok": true}
```

`/flaky`(3 回とも 503 になり、終了コード 1):

```text
attempt 1/3 failed (status=503, curl_exit=0) -> evidence/<実行ID>/attempt-1
attempt 2/3 failed (status=503, curl_exit=0) -> evidence/<実行ID>/attempt-2
attempt 3/3 failed (status=503, curl_exit=0) -> evidence/<実行ID>/attempt-3
EVIDENCE_DIR=evidence/<実行ID>
```

各 `attempt-N/` には `meta.txt` / `response-headers.txt` / `response-body.txt` / `curl-stderr.txt` ができる。`response-body.txt` は `{"error": "upstream_maintenance", "retry_after": 30}`、`meta.txt` の `curl_args` は `-H Authorization: [REDACTED]` になる。`grep -r secret-token evidence` は何も見つけない。

`evidence/` は `.gitignore` に入れてある。

## 確かめていない範囲

- 秘密情報の除去は、既知のヘッダ名(`Authorization` / `Cookie` / `X-Api-Key`)だけ。URL のクエリに入れたトークンや、応答の本文に含まれる秘密は消えない
- 実際の外部 API での失敗では試していない(ローカルのデモサーバーだけ)
- デモサーバーのポートは 8765 に固定している

## 記事

https://zenn.dev/liatris/articles/20261105-failure-evidence-capture

## ライセンス

MIT
