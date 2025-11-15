import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

HOST = "0.0.0.0"
PORT = int(os.getenv("HTTP_PORT", "8099"))
EVENT_INDEX = int(os.getenv("EVENT_INDEX", "0"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "info").lower()


def log(level, msg):
    levels = ["debug", "info", "warning", "error"]
    if levels.index(level) >= levels.index(LOG_LEVEL):
        print(f"[{level.upper()}] {msg}", flush=True)


def run_cli(cmd_args):
    """Run vico-cli command and return parsed JSON, or [] on error."""
    try:
        result = subprocess.run(
            ["vicohome", *cmd_args],
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        log("error", f"Error running vicohome CLI {' '.join(cmd_args)}: {e.stderr}")
        return []
    except json.JSONDecodeError as e:
        log("error", f"Error parsing JSON from vicohome CLI {' '.join(cmd_args)}: {e}")
        return []


def get_events():
    """All events."""
    return run_cli(["events", "list", "--format=json"])


def get_devices():
    """All devices (cameras)."""
    return run_cli(["devices", "list", "--format=json"])


def filter_events(events, device_id=None, device_name=None):
    """Filter events by deviceId or deviceName (contains)."""
    filtered = events

    if device_id:
        filtered = [
            e for e in filtered
            if str(e.get("deviceId") or e.get("deviceID") or "") == str(device_id)
        ]

    if device_name:
        dn = device_name.lower()
        filtered = [
            e for e in filtered
            if dn in str(e.get("deviceName") or "").lower()
        ]

    return filtered or events  # if nothing matched, fall back to all


def get_selected_event(device_id=None, device_name=None, index=None):
    events = get_events()
    if not events:
        return None

    if index is None:
        index = EVENT_INDEX

    filtered = filter_events(events, device_id, device_name)

    if index < 0 or index >= len(filtered):
        log("warning", f"Index {index} out of range for filtered list, using 0")
        index = 0

    return filtered[index]


class VicohomeHandler(BaseHTTPRequestHandler):
    def _set_headers(self, code=200, content_type="application/json"):
        self.send_response(code)
        self.send_header("Content-type", content_type)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/events":
            self.handle_events()
        elif parsed.path == "/devices":
            self.handle_devices()
        elif parsed.path == "/latest_video":
            self.handle_latest_video(parsed)
        elif parsed.path == "/latest_snapshot":
            self.handle_latest_snapshot(parsed)
        else:
            self._set_headers(404)
            self.wfile.write(b'{"error": "not found"}')

    # ----- JSON endpoints -----

    def handle_events(self):
        events = get_events()
        self._set_headers(200, "application/json")
        self.wfile.write(json.dumps(events).encode("utf-8"))

    def handle_devices(self):
        devices = get_devices()
        self._set_headers(200, "application/json")
        self.wfile.write(json.dumps(devices).encode("utf-8"))

    # ----- Video redirect -----

    def handle_latest_video(self, parsed):
        params = parse_qs(parsed.query)
        device_id = params.get("device_id", [None])[0]
        device_name = params.get("device_name", [None])[0]
        index_param = params.get("index", [None])[0]

        index = None
        if index_param is not None:
            try:
                index = int(index_param)
            except ValueError:
                log("warning", f"Invalid index parameter: {index_param}")

        event = get_selected_event(device_id=device_id, device_name=device_name, index=index)
        if not event:
            self._set_headers(500, "application/json")
            self.wfile.write(b'{"error": "no events available"}')
            return

        video_url = (
            event.get("videoUrl")
            or event.get("videoURL")
            or event.get("video_url")
        )
        if not video_url:
            self._set_headers(500, "application/json")
            self.wfile.write(b'{"error": "event has no videoUrl field"}')
            return

        log("info", f"Redirecting to video URL: {video_url}")
        self.send_response(302)
        self.send_header("Location", video_url)
        self.end_headers()

    # ----- Snapshot redirect -----

    def handle_latest_snapshot(self, parsed):
        params = parse_qs(parsed.query)
        device_id = params.get("device_id", [None])[0]
        device_name = params.get("device_name", [None])[0]
        index_param = params.get("index", [None])[0]

        index = None
        if index_param is not None:
            try:
                index = int(index_param)
            except ValueError:
                log("warning", f"Invalid index parameter: {index_param}")

        event = get_selected_event(device_id=device_id, device_name=device_name, index=index)
        if not event:
            self._set_headers(500, "application/json")
            self.wfile.write(b'{"error": "no events available"}')
            return

        # You may need to tweak these keys after looking at /events JSON:
        snapshot_url = (
            event.get("thumbnailUrl")
            or event.get("snapshotUrl")
            or event.get("imageUrl")
        )
        if not snapshot_url:
            self._set_headers(500, "application/json")
            self.wfile.write(b'{"error": "event has no snapshot/thumbnail URL field"}')
            return

        log("info", f"Redirecting to snapshot URL: {snapshot_url}")
        self.send_response(302)
        self.send_header("Location", snapshot_url)
        self.end_headers()


def run():
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, VicohomeHandler)
    log("info", f"Vicohome Bridge HTTP server running on {HOST}:{PORT}")
    httpd.serve_forever()


if __name__ == "__main__":
    run()