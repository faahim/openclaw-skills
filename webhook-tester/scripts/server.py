#!/usr/bin/env python3
"""Webhook Tester — Lightweight HTTP server to capture, inspect, and replay webhooks."""

import argparse
import datetime
import json
import os
import signal
import sys
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# Globals
WEBHOOK_DIR = Path(os.environ.get("WEBHOOK_TESTER_DIR", "./webhooks"))
RESPONSE_CODE = int(os.environ.get("WEBHOOK_TESTER_RESPONSE_CODE", 200))
RESPONSE_BODY = '{"status":"ok"}'
MAX_KEEP = int(os.environ.get("WEBHOOK_TESTER_MAX_KEEP", 1000))
MAX_LOG_BODY = 2000
DELAY_MS = 0
ROUTES = {}
counter_lock = threading.Lock()
counter = [0]
PID_FILE = None


def rotate_webhooks():
    """Remove oldest webhooks if over MAX_KEEP."""
    files = sorted(WEBHOOK_DIR.glob("*.json"))
    while len(files) > MAX_KEEP:
        files[0].unlink()
        files.pop(0)


class WebhookHandler(BaseHTTPRequestHandler):
    def _handle(self):
        import time
        if DELAY_MS > 0:
            time.sleep(DELAY_MS / 1000.0)

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b""

        # Parse body
        body_str = body.decode("utf-8", errors="replace")
        try:
            body_parsed = json.loads(body_str) if body_str.strip() else None
        except (json.JSONDecodeError, ValueError):
            body_parsed = None

        # Collect headers
        headers = dict(self.headers)

        # Determine response
        resp_code = RESPONSE_CODE
        resp_body = RESPONSE_BODY
        for route_path, (rc, rb) in ROUTES.items():
            if self.path.startswith(route_path):
                resp_code = rc
                resp_body = rb
                break

        # Build record
        now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
        with counter_lock:
            counter[0] += 1
            num = counter[0]

        safe_path = self.path.strip("/").replace("/", "_")[:50] or "root"
        filename = f"{num:04d}_{safe_path}_{now.strftime('%Y%m%d_%H%M%S')}.json"

        record = {
            "number": num,
            "timestamp": now.isoformat() + "Z",
            "method": self.command,
            "path": self.path,
            "headers": headers,
            "body_raw": body_str,
            "body_parsed": body_parsed,
            "content_length": content_length,
            "client": self.client_address[0],
        }

        # Save
        WEBHOOK_DIR.mkdir(parents=True, exist_ok=True)
        filepath = WEBHOOK_DIR / filename
        with open(filepath, "w") as f:
            json.dump(record, f, indent=2)

        rotate_webhooks()

        # Log
        truncated = body_str[:MAX_LOG_BODY] + ("..." if len(body_str) > MAX_LOG_BODY else "")
        ct = headers.get("Content-Type", "unknown")
        print(f"[{now.strftime('%Y-%m-%d %H:%M:%S')}] {self.command} {self.path} — {resp_code} ({ct}, {content_length} bytes)")

        # Print notable headers
        notable = ["X-Stripe-Signature", "X-GitHub-Event", "X-GitHub-Delivery",
                    "X-Slack-Signature", "X-Twilio-Signature", "X-Webhook-Secret",
                    "Authorization", "X-Request-Id"]
        for h in notable:
            if h in headers:
                print(f"  {h}: {headers[h]}")

        if truncated.strip():
            print(f"  Body: {truncated}")
        print(f"  Saved: {filepath}")
        print()

        # Respond
        self.send_response(resp_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(resp_body.encode())

    def do_POST(self):
        self._handle()

    def do_PUT(self):
        self._handle()

    def do_PATCH(self):
        self._handle()

    def do_DELETE(self):
        self._handle()

    def do_GET(self):
        # GET /status returns server info
        if self.path == "/status":
            files = list(WEBHOOK_DIR.glob("*.json"))
            status = {"running": True, "captured": len(files), "port": self.server.server_port}
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(status).encode())
            return
        self._handle()

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def log_message(self, format, *args):
        pass  # Suppress default logging


def parse_route(route_str):
    """Parse route spec: '/path:code:body'"""
    parts = route_str.split(":", 2)
    path = parts[0]
    code = int(parts[1]) if len(parts) > 1 else 200
    body = parts[2] if len(parts) > 2 else '{"status":"ok"}'
    return path, code, body


def main():
    global WEBHOOK_DIR, RESPONSE_CODE, RESPONSE_BODY, MAX_KEEP, MAX_LOG_BODY, DELAY_MS, ROUTES, PID_FILE

    parser = argparse.ArgumentParser(description="Webhook Tester — Capture incoming webhooks")
    parser.add_argument("--port", type=int, default=int(os.environ.get("WEBHOOK_TESTER_PORT", 9876)))
    parser.add_argument("--dir", type=str, default=str(WEBHOOK_DIR))
    parser.add_argument("--response-code", type=int, default=RESPONSE_CODE)
    parser.add_argument("--response-body", type=str, default=RESPONSE_BODY)
    parser.add_argument("--max-keep", type=int, default=MAX_KEEP)
    parser.add_argument("--max-log-body", type=int, default=MAX_LOG_BODY)
    parser.add_argument("--delay", type=int, default=0, help="Response delay in ms")
    parser.add_argument("--daemon", action="store_true", help="Run in background")
    parser.add_argument("--route", action="append", help="Route-specific response: /path:code:body")
    args = parser.parse_args()

    WEBHOOK_DIR = Path(args.dir)
    RESPONSE_CODE = args.response_code
    RESPONSE_BODY = args.response_body
    MAX_KEEP = args.max_keep
    MAX_LOG_BODY = args.max_log_body
    DELAY_MS = args.delay

    if args.route:
        for r in args.route:
            path, code, body = parse_route(r)
            ROUTES[path] = (code, body)

    WEBHOOK_DIR.mkdir(parents=True, exist_ok=True)

    # Count existing webhooks to set counter
    existing = sorted(WEBHOOK_DIR.glob("*.json"))
    if existing:
        try:
            with open(existing[-1]) as f:
                last = json.load(f)
                counter[0] = last.get("number", len(existing))
        except Exception:
            counter[0] = len(existing)

    if args.daemon:
        pid = os.fork()
        if pid > 0:
            pid_file = WEBHOOK_DIR / "server.pid"
            pid_file.write_text(str(pid))
            print(f"🔗 Webhook Tester daemonized (PID {pid}) on port {args.port}")
            print(f"📁 Payloads saved to {WEBHOOK_DIR}/")
            sys.exit(0)
        # Child continues
        os.setsid()

    PID_FILE = WEBHOOK_DIR / "server.pid"

    server = HTTPServer(("0.0.0.0", args.port), WebhookHandler)

    def shutdown(sig, frame):
        print("\n🛑 Webhook Tester stopped.")
        if PID_FILE and PID_FILE.exists():
            PID_FILE.unlink()
        server.shutdown()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    if not args.daemon:
        PID_FILE.write_text(str(os.getpid()))

    print(f"🔗 Webhook Tester listening on http://0.0.0.0:{args.port}")
    print(f"📁 Payloads saved to {WEBHOOK_DIR}/")
    if ROUTES:
        for p, (c, b) in ROUTES.items():
            print(f"📌 Route {p} → {c}: {b[:50]}")
    if DELAY_MS > 0:
        print(f"⏱️  Response delay: {DELAY_MS}ms")
    print("Press Ctrl+C to stop\n")

    server.serve_forever()


if __name__ == "__main__":
    main()
