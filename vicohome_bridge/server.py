import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = "0.0.0.0"
PORT = int(os.getenv("HTTP_PORT", "8099"))
EVENT_INDEX = int(os.getenv("EVENT_INDEX", "0"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "info").lower()


def log(level, msg):
    levels = ["debug", "info", "warning", "error"]
    if levels.index(level) >= levels.index(LOG_LEVEL):
        print(f"[{level.upper()}] {msg}", flush=True)


def get_events():
    """
    Runs `vicohome events list --format=json` and returns the parsed JSON list.
    """
    try:
        result = subprocess.run(
            ["vicohome", "events", "list", "--format=json"],
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        log("error", f"Error running vicohome CLI: {e.stderr}")
        return []
    except json.JSONDecodeError as e:
        log("error", f"Error parsing vicohome JSON: {e}")
        return []


def get_selected_event():
    events = get_events()
    if not events:
        return None
    if EVENT_INDEX < 0 or EVENT_INDEX >= len(events):
        log("warning", f"EVENT_INDEX {EVENT_INDEX} out of range, using 0")
        return events[0]
    return events[EVENT_INDEX]


class VicohomeHandler(BaseHTTPRequestHandler):
    def _set_headers(self, code=200, content_type="application/json"):
        self.send_response(code)
        self.send_header("Content-type", content_type)
        self.end_headers()

    def do_GET(self):
        if self.path == "/events":
            self.handle_events()
        elif self.path == "/latest_video":
            self.handle_latest_video()
        else:
            self._set_headers(404)
            self.wfile.write(b'{"error": "not found"}')

    def handle_events(self):
        events = get_events()
        self._set_headers(200, "application/json")
        self.wfile.write(json.dumps(events).encode("utf-8"))

    def handle_latest_video(self):
        event = get_selected_event()
        if not event:
            self._set_headers(500, "application/json")
            self.wfile.write(b'{"error": "no events available"}')
            return

        # Adjust this key if needed based on your actual CLI output:
        video_url = event.get("videoUrl") or event.get("videoURL")
        if not video_url:
            self._set_headers(500, "application/json")
            self.wfile.write(b'{"error": "event has no videoUrl field"}')
            return

        log("info", f"Redirecting to video URL: {video_url}")

        # HTTP 302 redirect to the real Vicohome video URL
        self.send_response(302)
        self.send_header("Location", video_url)
        self.end_headers()


def run():
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, VicohomeHandler)
    log("info", f"Vicohome Bridge HTTP server running on {HOST}:{PORT}")
    httpd.serve_forever()


if __name__ == "__main__":
    run()
