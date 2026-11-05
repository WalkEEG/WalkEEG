#!/usr/bin/env bash
# Local preview server for the WalkEEG docs.
#
# Docsify requests markdown files WITHOUT the .md extension
# (e.g. `/wiki/basic-principle`), so a plain static server returns 404.
# This wrapper serves the wiki directory and rewrites extensionless
# requests to their .md counterpart.
#
# Usage:  python3 serve.py [port]   (default 8813)

import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8813
ROOT = os.path.dirname(os.path.abspath(__file__))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def translate_path(self, path):
        path = path.split('?', 1)[0].split('#', 1)[0]

        # /wiki/... -> strip the prefix, the docs live at ROOT/wiki
        if path.startswith('/wiki'):
            rel = path[len('/wiki'):].lstrip('/')
        else:
            rel = path.lstrip('/')

        fs = os.path.join(ROOT, 'wiki', rel)

        if os.path.isdir(fs):
            idx = os.path.join(fs, 'index.html')
            if os.path.exists(idx):
                return idx
            return fs

        if os.path.exists(fs):
            return fs

        # Extensionless -> try .md, then /README.md
        if not os.path.splitext(fs)[1]:
            if os.path.exists(fs + '.md'):
                return fs + '.md'
            if os.path.exists(os.path.join(fs, 'README.md')):
                return os.path.join(fs, 'README.md')

        return fs

    def end_headers(self):
        # Never cache during development
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


os.chdir(os.path.join(ROOT, 'wiki'))

with socketserver.TCPServer(('', PORT), Handler) as httpd:
    httpd.allow_reuse_address = True
    print(f"WalkEEG docs on http://localhost:{PORT}/wiki/")
    httpd.serve_forever()
