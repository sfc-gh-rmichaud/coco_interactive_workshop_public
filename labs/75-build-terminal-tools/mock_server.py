"""Loopback-only mock. No Snowflake credentials or paid calls."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import time


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        if length > 8192:
            self.send_error(413)
            return
        self.rfile.read(length)
        if self.path == '/slow':
            time.sleep(2)
        code = {'/unauthorized':401, '/throttle':429}.get(self.path, 200)
        payload = b'not-json' if self.path == '/malformed' else json.dumps({'ok':True, 'text':'synthetic reply'}).encode()
        self.send_response(code)
        self.send_header('Content-Type','application/json')
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Mock listening on http://127.0.0.1:{server.server_port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
