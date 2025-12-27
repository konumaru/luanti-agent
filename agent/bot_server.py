#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from queue import SimpleQueue
from urllib.parse import urlparse

QUEUE = SimpleQueue()


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/health":
            self._send_json(200, {"ok": True})
            return

        if path != "/next":
            self._send_json(404, {"error": "not found"})
            return

        commands = []
        while not QUEUE.empty():
            commands.append(QUEUE.get())
        self._send_json(200, {"commands": commands})

    def do_POST(self):
        path = urlparse(self.path).path
        if path != "/enqueue":
            self._send_json(404, {"error": "not found"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode("utf-8") if length > 0 else ""
        try:
            payload = json.loads(body) if body else None
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid json"})
            return

        if not payload:
            self._send_json(400, {"error": "missing payload"})
            return

        commands = payload if isinstance(payload, list) else [payload]
        for cmd in commands:
            QUEUE.put(cmd)

        self._send_json(200, {"queued": len(commands)})

    def log_message(self, format, *args):
        return


def main():
    server = HTTPServer(("0.0.0.0", 8000), Handler)
    print("python bot server listening on http://0.0.0.0:8000")
    server.serve_forever()


if __name__ == "__main__":
    main()
