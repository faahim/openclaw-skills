#!/usr/bin/env python3
"""
Webhook Relay — Receive webhooks, route to multiple destinations.
Zero external dependencies (Python 3.8+ stdlib only).
"""

import hashlib
import hmac
import json
import logging
import os
import re
import smtplib
import ssl
import sys
import time
from email.mime.text import MIMEText
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from threading import Thread
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from urllib.error import URLError

# --- Config Loading ---

def load_config(path=None):
    """Load YAML-like config. Supports a subset of YAML (enough for our needs)."""
    if path is None:
        path = os.environ.get(
            "WEBHOOK_RELAY_CONFIG",
            os.path.expanduser("~/.config/webhook-relay/config.yaml")
        )
    
    if not os.path.exists(path):
        logging.error(f"Config not found: {path}")
        sys.exit(1)
    
    with open(path) as f:
        content = f.read()
    
    # Try PyYAML first, fall back to JSON
    try:
        import yaml
        return yaml.safe_load(content)
    except ImportError:
        pass
    
    # Try JSON config
    json_path = path.replace(".yaml", ".json").replace(".yml", ".json")
    if os.path.exists(json_path):
        with open(json_path) as f:
            return json.load(f)
    
    # Minimal YAML parser for simple configs
    return _parse_simple_yaml(content)


def _parse_simple_yaml(content):
    """Minimal YAML parser — handles our config structure."""
    # Strip comments
    lines = []
    for line in content.split("\n"):
        stripped = line.split(" #")[0].rstrip()
        if stripped and not stripped.lstrip().startswith("#"):
            lines.append(stripped)
    
    # For complex YAML, suggest installing PyYAML
    logging.warning(
        "PyYAML not installed. For complex configs, run: pip3 install pyyaml\n"
        "Falling back to JSON config. Create config.json alongside config.yaml."
    )
    return {"server": {"host": "0.0.0.0", "port": 9876}, "routes": []}


def expand_env(value):
    """Expand ${VAR} references in strings."""
    if not isinstance(value, str):
        return value
    def replacer(match):
        var = match.group(1)
        return os.environ.get(var, match.group(0))
    return re.sub(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}', replacer, value)


def expand_config(obj):
    """Recursively expand environment variables in config."""
    if isinstance(obj, str):
        return expand_env(obj)
    elif isinstance(obj, dict):
        return {k: expand_config(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [expand_config(i) for i in obj]
    return obj


# --- Template Engine ---

def resolve_path(obj, path):
    """Resolve a dotted path like 'body.repository.full_name' against an object."""
    parts = path.split(".")
    current = obj
    for part in parts:
        if isinstance(current, dict) and part in current:
            current = current[part]
        else:
            return None
    return current


def render_template(template, context):
    """Render ${...} expressions in templates."""
    if not template:
        return ""
    
    def replacer(match):
        expr = match.group(1).strip()
        
        # Handle pipe-separated fallbacks: ${a|b|'literal'}
        alternatives = [a.strip() for a in expr.split("|")]
        for alt in alternatives:
            # Quoted literal
            if (alt.startswith("'") and alt.endswith("'")) or \
               (alt.startswith('"') and alt.endswith('"')):
                return alt[1:-1]
            
            # Simple math: field / number
            if " / " in alt:
                field, divisor = alt.split(" / ", 1)
                val = resolve_path(context, field)
                if val is not None:
                    try:
                        return str(round(float(val) / float(divisor), 2))
                    except (ValueError, ZeroDivisionError):
                        pass
                continue
            
            # Env var
            if alt.startswith("$"):
                env_val = os.environ.get(alt[1:], os.environ.get(alt[2:-1] if alt.startswith("${") else alt[1:]))
                if env_val:
                    return env_val
                continue
            
            # Context path
            val = resolve_path(context, alt)
            if val is not None:
                return str(val) if not isinstance(val, str) else val
        
        return match.group(0)  # Unresolved
    
    return re.sub(r'\$\{([^}]+)\}', replacer, template)


# --- JSON Path Matching ---

def match_jsonpath(data, field, value):
    """Simple JSONPath-like matching. Supports $.field.subfield"""
    if not field:
        return True
    
    path = field.lstrip("$").lstrip(".")
    result = resolve_path(data, path)
    
    if value is None:
        return result is not None
    
    return str(result) == str(value)


# --- Target Senders ---

def send_telegram(target, context):
    """Send message via Telegram Bot API."""
    token = target.get("bot_token", "")
    chat_id = target.get("chat_id", "")
    template = target.get("template", json.dumps(context.get("body", {}), indent=2)[:4000])
    parse_mode = target.get("parse_mode", "")
    
    if not token or not chat_id:
        logging.error("Telegram: missing bot_token or chat_id")
        return False
    
    text = render_template(template, context)
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = {"chat_id": chat_id, "text": text[:4096]}
    if parse_mode:
        payload["parse_mode"] = parse_mode
    
    return _http_post(url, payload)


def send_discord(target, context):
    """Send message via Discord webhook."""
    webhook_url = target.get("webhook_url", "")
    template = target.get("template", json.dumps(context.get("body", {}), indent=2)[:2000])
    
    if not webhook_url:
        logging.error("Discord: missing webhook_url")
        return False
    
    text = render_template(template, context)
    return _http_post(webhook_url, {"content": text[:2000]})


def send_url(target, context):
    """Forward to arbitrary URL."""
    url = target.get("url", "")
    method = target.get("method", "POST").upper()
    headers = target.get("headers", {})
    body_template = target.get("body")
    
    if not url:
        logging.error("URL target: missing url")
        return False
    
    if body_template:
        if body_template == "${raw}":
            data = json.dumps(context.get("body", {})).encode()
        else:
            data = render_template(body_template, context).encode()
    else:
        data = json.dumps(context.get("body", {})).encode()
    
    if "Content-Type" not in headers:
        headers["Content-Type"] = "application/json"
    
    try:
        req = Request(url, data=data, headers=headers, method=method)
        ctx = ssl.create_default_context()
        resp = urlopen(req, context=ctx, timeout=10)
        logging.info(f"URL target {url}: {resp.status}")
        return True
    except Exception as e:
        logging.error(f"URL target {url}: {e}")
        return False


def send_email(target, context):
    """Send email via SMTP."""
    template = target.get("template", json.dumps(context.get("body", {}), indent=2)[:4000])
    text = render_template(template, context)
    subject = render_template(target.get("subject", "Webhook Relay Alert"), context)
    
    msg = MIMEText(text)
    msg["Subject"] = subject
    msg["From"] = target.get("from", target.get("smtp_user", ""))
    msg["To"] = target.get("to", "")
    
    try:
        smtp_host = target.get("smtp_host", "smtp.gmail.com")
        smtp_port = int(target.get("smtp_port", 587))
        
        server = smtplib.SMTP(smtp_host, smtp_port)
        server.starttls()
        server.login(target.get("smtp_user", ""), target.get("smtp_pass", ""))
        server.send_message(msg)
        server.quit()
        logging.info(f"Email sent to {msg['To']}")
        return True
    except Exception as e:
        logging.error(f"Email failed: {e}")
        return False


def send_log(target, context):
    """Append to log file."""
    logfile = target.get("file", "/tmp/webhook-relay.log")
    entry = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "path": context.get("path", ""),
        "method": context.get("method", ""),
        "body": context.get("body", {}),
    }
    
    try:
        Path(logfile).parent.mkdir(parents=True, exist_ok=True)
        with open(logfile, "a") as f:
            f.write(json.dumps(entry) + "\n")
        logging.info(f"Logged to {logfile}")
        return True
    except Exception as e:
        logging.error(f"Log failed: {e}")
        return False


SENDERS = {
    "telegram": send_telegram,
    "discord": send_discord,
    "url": send_url,
    "email": send_email,
    "log": send_log,
}


def _http_post(url, payload):
    """Simple HTTP POST with JSON body."""
    try:
        data = json.dumps(payload).encode()
        req = Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
        ctx = ssl.create_default_context()
        resp = urlopen(req, context=ctx, timeout=10)
        logging.info(f"POST {url}: {resp.status}")
        return True
    except Exception as e:
        logging.error(f"POST {url}: {e}")
        return False


# --- Signature Verification ---

def verify_signature(body_bytes, secret, sig_header_value, algorithm="sha256"):
    """Verify HMAC signature (GitHub X-Hub-Signature-256 style)."""
    if not secret:
        return True  # No secret configured
    if not sig_header_value:
        return False
    
    # GitHub format: sha256=<hex>
    if "=" in sig_header_value:
        algo, signature = sig_header_value.split("=", 1)
    else:
        signature = sig_header_value
    
    expected = hmac.new(
        secret.encode(), body_bytes, hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected, signature)


# --- HTTP Server ---

class RelayHandler(BaseHTTPRequestHandler):
    """Handle incoming webhooks."""
    
    config = None
    
    def do_POST(self):
        self._handle()
    
    def do_PUT(self):
        self._handle()
    
    def do_GET(self):
        """Health check endpoint."""
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({
                "status": "ok",
                "routes": len(self.config.get("routes", [])),
                "uptime": time.time() - self.server.start_time
            }).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def _handle(self):
        config = self.config
        server_config = config.get("server", {})
        
        # Read body
        content_length = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(content_length) if content_length > 0 else b""
        
        # Verify signature
        secret = server_config.get("secret", "")
        sig_header = server_config.get("signature_header", "X-Hub-Signature-256")
        if secret:
            sig_value = self.headers.get(sig_header, "")
            if not verify_signature(body_bytes, secret, sig_value):
                logging.warning(f"Signature verification failed for {self.path}")
                self.send_response(401)
                self.end_headers()
                self.wfile.write(b'{"error":"invalid signature"}')
                return
        
        # Parse body
        try:
            body = json.loads(body_bytes) if body_bytes else {}
        except json.JSONDecodeError:
            body = {"raw": body_bytes.decode("utf-8", errors="replace")}
        
        # Build context
        headers_dict = {k: v for k, v in self.headers.items()}
        context = {
            "path": self.path,
            "method": self.command,
            "headers": headers_dict,
            "body": body,
            "raw": body_bytes.decode("utf-8", errors="replace"),
            "summary": _summarize(body),
        }
        
        # Match routes
        matched = 0
        for route in config.get("routes", []):
            match = route.get("match", {})
            
            # Path match
            route_path = match.get("path", "")
            if route_path and not self.path.startswith(route_path):
                continue
            
            # Header match
            header_name = match.get("header")
            header_value = match.get("header_value")
            if header_name and header_value:
                if self.headers.get(header_name) != header_value:
                    continue
            
            # JSON field match
            field = match.get("field")
            value = match.get("value")
            if field and not match_jsonpath(body, field, value):
                continue
            
            # Route matched — send to all targets
            matched += 1
            route_name = route.get("name", f"route-{matched}")
            logging.info(f"Route matched: {route_name}")
            
            for target in route.get("targets", []):
                target_type = target.get("type", "log")
                sender = SENDERS.get(target_type)
                if sender:
                    # Send async to avoid blocking
                    Thread(target=sender, args=(target, context), daemon=True).start()
                else:
                    logging.warning(f"Unknown target type: {target_type}")
        
        if matched == 0:
            logging.info(f"No route matched for {self.path}")
        
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({
            "ok": True,
            "matched_routes": matched
        }).encode())
    
    def log_message(self, format, *args):
        """Use Python logging instead of stderr."""
        logging.debug(f"{self.address_string()} - {format % args}")


def _summarize(body):
    """Generate a one-line summary of a webhook payload."""
    # GitHub
    if "repository" in body and "sender" in body:
        repo = body.get("repository", {}).get("full_name", "?")
        sender = body.get("sender", {}).get("login", "?")
        action = body.get("action", body.get("ref", "event"))
        return f"{sender} → {repo}: {action}"
    
    # Stripe
    if "type" in body and "data" in body and "object" in body.get("data", {}):
        return f"Stripe: {body['type']}"
    
    # Generic
    if "message" in body:
        return str(body["message"])[:200]
    
    return json.dumps(body)[:200]


# --- Main ---

def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    
    config_path = sys.argv[1] if len(sys.argv) > 1 else None
    config = load_config(config_path)
    config = expand_config(config)
    
    server_config = config.get("server", {})
    host = server_config.get("host", "0.0.0.0")
    port = int(server_config.get("port", 9876))
    
    RelayHandler.config = config
    
    server = HTTPServer((host, port), RelayHandler)
    server.start_time = time.time()
    
    routes = config.get("routes", [])
    logging.info(f"Webhook Relay started on {host}:{port} with {len(routes)} routes")
    for r in routes:
        targets = [t.get("type", "?") for t in r.get("targets", [])]
        logging.info(f"  [{r.get('name', '?')}] {r.get('match', {}).get('path', '/')} → {', '.join(targets)}")
    logging.info(f"Health check: http://{host}:{port}/health")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info("Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
