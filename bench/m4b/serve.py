# Usage: python3 -I serve.py <dir> <port>
# Serves <dir>/<name> with Range support; ?ct=<mime> sets the Content-Type.
import os, re, sys, urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

ROOT, PORT = sys.argv[1], int(sys.argv[2])

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        name = os.path.basename(urllib.parse.unquote(u.path))
        path = os.path.join(ROOT, name)
        if not os.path.isfile(path):
            self.send_error(404); return
        ct = urllib.parse.parse_qs(u.query).get("ct", ["application/octet-stream"])[0]
        data = open(path, "rb").read()
        size = len(data)
        rng = self.headers.get("Range")
        m = re.match(r"bytes=(\d*)-(\d*)", rng or "")
        if m:
            start = int(m.group(1)) if m.group(1) else size - int(m.group(2))
            end = int(m.group(2)) if m.group(1) and m.group(2) else size - 1
            end = min(end, size - 1)
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        else:
            start, end = 0, size - 1
            self.send_response(200)
        self.send_header("Content-Type", ct)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(end - start + 1))
        self.end_headers()
        try:
            self.wfile.write(data[start:end + 1])
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.headers.get("Range"), fmt % args))

ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
