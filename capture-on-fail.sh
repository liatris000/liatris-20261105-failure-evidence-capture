#!/usr/bin/env bash
# capture-on-fail.sh: 外部 API 呼び出しを包み、失敗した試行だけ証拠を保存する
# 使い方: EVIDENCE_DIR=evidence MAX_ATTEMPTS=3 ./capture-on-fail.sh URL [curl の追加引数...]
set -u

url="${1:?usage: $0 URL [curl args...]}"
shift
evidence_root="${EVIDENCE_DIR:-evidence}"
max_attempts="${MAX_ATTEMPTS:-3}"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
run_dir="${evidence_root}/${run_id}"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# Authorization / Cookie / 各種キーのヘッダ値は保存前に潰す
redact() {
  sed -E 's/([Aa]uthorization|[Cc]ookie|[Xx]-[Aa]pi-[Kk]ey): *[^ ]+( [^ -][^ ]*)?/\1: [REDACTED]/g'
}

attempt=1
while [ "${attempt}" -le "${max_attempts}" ]; do
  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # -sS: 進捗は消すがエラーは出す / -D: 応答ヘッダ / -w: ステータスと所要時間
  code_and_time="$(curl -sS --max-time 10 \
      -D "${tmp}/headers" -o "${tmp}/body" \
      -w '%{http_code} %{time_total}' "$@" "${url}" 2>"${tmp}/stderr")"
  curl_rc=$?
  http_code="${code_and_time%% *}"
  elapsed="${code_and_time##* }"

  if [ "${curl_rc}" -eq 0 ] && [ "${http_code}" -ge 200 ] && [ "${http_code}" -lt 300 ]; then
    cat "${tmp}/body"
    exit 0
  fi

  # 失敗した試行ごとに別ディレクトリへ残す(後の試行で上書きしない)
  dir="${run_dir}/attempt-${attempt}"
  mkdir -p "${dir}"
  {
    echo "started_at: ${started}"
    echo "url: ${url}"
    echo "curl_exit: ${curl_rc}"
    echo "http_status: ${http_code}"
    echo "time_total_sec: ${elapsed}"
    echo "curl_args: $(printf '%s ' "$@" | redact)"
  } > "${dir}/meta.txt"
  redact < "${tmp}/headers" > "${dir}/response-headers.txt" 2>/dev/null || true
  cp "${tmp}/body" "${dir}/response-body.txt" 2>/dev/null || true
  cp "${tmp}/stderr" "${dir}/curl-stderr.txt"

  echo "attempt ${attempt}/${max_attempts} failed (status=${http_code}, curl_exit=${curl_rc}) -> ${dir}" >&2
  attempt=$((attempt + 1))
  [ "${attempt}" -le "${max_attempts}" ] && sleep "${RETRY_WAIT:-1}"
done

echo "EVIDENCE_DIR=${run_dir}" >&2
exit 1
