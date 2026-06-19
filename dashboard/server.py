#!/usr/bin/env python3
"""
17BA Bad Apple Enterprise — Command Center Server
Reads MT5 status JSON files and serves the Jarvis dashboard.
Run: python server.py
Open: http://localhost:8888
"""

import http.server
import json
import os
import time
from pathlib import Path
from datetime import datetime

PORT = 8888

# MT5 writes status files to the Common\Files folder so any terminal instance
# uses the same path. Override MT5_PATH if your setup differs.
MT5_PATH_OVERRIDE = None  # e.g. r"C:\Users\YourName\AppData\Roaming\MetaQuotes\Terminal\Common\Files"

def find_mt5_path():
    if MT5_PATH_OVERRIDE:
        return Path(MT5_PATH_OVERRIDE)
    candidates = [
        Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal" / "Common" / "Files",
        Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files",
        Path("/root/.wine/drive_c/users/root/AppData/Roaming/MetaQuotes/Terminal/Common/Files"),
        Path.home() / ".wine" / "drive_c" / "users" / "root" / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files",
        Path("."),  # fallback: current directory (for testing with mock files)
    ]
    for p in candidates:
        if p.exists():
            return p
    return Path(".")

def read_bot(filename, ea_name):
    mt5_path = find_mt5_path()
    filepath = mt5_path / filename
    offline = {
        "ea": ea_name, "status": "OFFLINE", "symbol": "—",
        "timestamp": "", "committed": 0,
        "balance": 0, "equity": 0, "floating_pl": 0,
        "drawdown_pct": 0, "guard_pct": 0, "basket_profit": 0,
        "atr_current": 0, "vol_elevated": False,
        "bid": 0, "ask": 0, "recovery_level": 0,
        "max_levels": 0, "pending_count": 0,
    }
    try:
        if not filepath.exists():
            return offline
        age = time.time() - filepath.stat().st_mtime
        if age > 60:
            offline["status"] = "STALE"
            offline["stale_seconds"] = round(age)
            return offline
        with open(filepath, "r") as f:
            data = json.load(f)
        data["file_age_seconds"] = round(age, 1)
        return data
    except Exception as e:
        offline["status"] = "ERROR"
        offline["error"] = str(e)
        return offline


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._serve_file("index.html", "text/html; charset=utf-8")
        elif self.path == "/api/status":
            self._serve_api()
        else:
            self.send_error(404)

    def _serve_file(self, name, ctype):
        p = Path(__file__).parent / name
        try:
            data = p.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", len(data))
            self.end_headers()
            self.wfile.write(data)
        except FileNotFoundError:
            self.send_error(404)

    def _serve_api(self):
        payload = json.dumps({
            "server_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "mt5_path": str(find_mt5_path()),
            "chakka":   read_bot("17ba_chakka_status.json",   "Chakka"),
            "quasheba": read_bot("17ba_quasheba_status.json", "Quasheba"),
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(payload))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_):
        pass  # keep console clean


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), Handler)
    mt5 = find_mt5_path()
    print(f"\n  17BA BAD APPLE COMMAND CENTER")
    print(f"  ─────────────────────────────")
    print(f"  Dashboard : http://localhost:{PORT}")
    print(f"  MT5 path  : {mt5}")
    print(f"  Status    : watching for 17ba_chakka_status.json")
    print(f"              and 17ba_quasheba_status.json")
    print(f"\n  Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("  Server stopped.")
