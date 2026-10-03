#!/usr/bin/env python3
"""Lokaler Testserver fuer die Pester-Tests von CDT-STANDARD-INSTALL-DE_LANG.ps1.

Lauscht ausschliesslich auf 127.0.0.1 (Port 0 = frei waehlbar) und gibt "READY <port>" aus.

Modi:
  range    HTTP mit Range-Unterstuetzung (206 + Content-Range)
  norange  HTTP ohne Range-Unterstuetzung (immer 200 + kompletter Inhalt)
  tls      wie "range", aber HTTPS mit selbstsigniertem Zertifikat (certfile/keyfile)
  proxy    Minimal-Proxy, beantwortet CONNECT mit dem angegebenen Status (z. B. 407 oder 403)

Pfade: /file.iso, /redirect/<n>, /forbidden, /stats (JSON-Zaehler), alles andere 404.
"""
import http.server
import json
import socket
import socketserver
import ssl
import sys
import threading


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):  # keine Konsolenausgabe
        pass

    def _empty(self, status, headers=None):
        self.send_response(status)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header('Content-Length', '0')
        self.end_headers()

    def do_GET(self):
        srv = self.server
        srv.stats['requests'] += 1
        path = self.path
        data = srv.payload
        if path == '/stats':
            body = json.dumps(srv.stats).encode('ascii')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path.startswith('/redirect/'):
            n = int(path.split('/')[2])
            loc = '/file.iso' if n <= 0 else '/redirect/%d' % (n - 1)
            self._empty(302, {'Location': loc})
            return
        if path == '/forbidden':
            self._empty(403)
            return
        if path != '/file.iso':
            self._empty(404)
            return
        rng = self.headers.get('Range')
        if srv.mode in ('range', 'tls') and rng and rng.startswith('bytes='):
            start_s, end_s = rng[6:].split('-', 1)
            start = int(start_s)
            end = int(end_s) if end_s else len(data) - 1
            end = min(end, len(data) - 1)
            body = data[start:end + 1]
            self.send_response(206)
            self.send_header('Content-Range', 'bytes %d-%d/%d' % (start, end, len(data)))
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self._write(body)
            return
        self.send_response(200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self._write(data)

    def _write(self, body):
        try:
            chunk = 65536
            for i in range(0, len(body), chunk):
                self.wfile.write(body[i:i + chunk])
            self.server.stats['completed'] += 1
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError, OSError):
            self.server.stats['aborted'] += 1


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def run_proxy(status):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('127.0.0.1', 0))
    sock.listen(16)
    print('READY %d' % sock.getsockname()[1], flush=True)

    def handle(conn):
        try:
            conn.settimeout(10)
            buf = b''
            while b'\r\n\r\n' not in buf and len(buf) < 65536:
                part = conn.recv(4096)
                if not part:
                    break
                buf += part
            reason = {407: 'Proxy Authentication Required', 403: 'Forbidden'}.get(status, 'Status')
            extra = 'Proxy-Authenticate: Negotiate\r\nProxy-Authenticate: NTLM\r\n' if status == 407 else ''
            conn.sendall(('HTTP/1.1 %d %s\r\n%sContent-Length: 0\r\nConnection: close\r\n\r\n' % (status, reason, extra)).encode('ascii'))
        except OSError:
            pass
        finally:
            conn.close()

    while True:
        c, _ = sock.accept()
        threading.Thread(target=handle, args=(c,), daemon=True).start()


def main():
    mode = sys.argv[1]
    size = int(sys.argv[2]) if len(sys.argv) > 2 else 1048576
    if mode == 'proxy':
        run_proxy(int(sys.argv[3]) if len(sys.argv) > 3 else 407)
        return
    srv = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    srv.mode = mode
    srv.payload = (b'CDT-DE-LANG-TEST' * (size // 16 + 1))[:size]
    srv.stats = {'requests': 0, 'completed': 0, 'aborted': 0}
    if mode == 'tls':
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(sys.argv[3], sys.argv[4])
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    print('READY %d' % srv.server_address[1], flush=True)
    srv.serve_forever()


if __name__ == '__main__':
    main()
