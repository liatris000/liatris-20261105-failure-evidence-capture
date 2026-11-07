"""失敗を再現するローカルサーバー。/flaky は 503 と本文を返し、/ok は 200 を返す。"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/flaky":
            body = json.dumps({"error": "upstream_maintenance", "retry_after": 30}).encode()
            self.send_response(503)
            self.send_header("Retry-After", "30")
        else:
            body = b'{"ok": true}'
            self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args: object) -> None:
        pass


HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
