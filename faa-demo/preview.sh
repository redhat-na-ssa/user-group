#!/usr/bin/env bash
# Preview the slide decks locally, laid out like the cluster and GitHub Pages
# sites: http://localhost:8000/ (deck list), .../demo1-fundamentals/ etc.
#
# The decks, images and shared theme are symlinked from this working copy, so
# an edit shows up on a browser refresh - no rebuild. reveal.js, the fonts and
# the QR code library come from npm (first run only, or with --refresh).
#
#   faa-demo/preview.sh [--refresh] [port]
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${REPO}/.preview"
REFRESH=false
[[ "${1:-}" == "--refresh" ]] && { REFRESH=true; shift; }
PORT="${1:-8000}"

if ${REFRESH} || [[ ! -d "${OUT}/reveal" ]]; then
  echo "Installing reveal.js, fonts and QR code library into ${OUT}"
  rm -rf "${OUT}" && mkdir -p "${OUT}/npm"
  cp "${REPO}/faa-demo/slides-site/package.json" "${OUT}/npm/"
  (cd "${OUT}/npm" && npm install --omit=dev --no-audit --no-fund >/dev/null)
  mkdir -p "${OUT}/reveal" "${OUT}/fonts" "${OUT}/lib"
  cp -r "${OUT}/npm/node_modules/reveal.js/dist/." "${OUT}/reveal/"
  cp "${OUT}/npm/node_modules/qrcode-generator/dist/qrcode.js" "${OUT}/lib/"
  for f in red-hat-display red-hat-text red-hat-mono; do
    cp -r "${OUT}/npm/node_modules/@fontsource/$f" "${OUT}/fonts/$f"
  done
  rm -rf "${OUT}/npm"
fi

# Same layout as the published site (see .github/workflows/pages.yml)
cp "${REPO}/faa-demo/slides-site/site/fonts/fonts.css" "${OUT}/fonts/"
ln -sfn "${REPO}/common/deck" "${OUT}/common"
"${REPO}/.venv/bin/python" - "${REPO}" "${OUT}" <<'EOF'
import os, sys, yaml, jinja2
repo, out = sys.argv[1:]
decks = yaml.safe_load(open(f"{repo}/faa-demo/playbook.yml"))[0]["vars"]["decks"]
env = jinja2.Environment(loader=jinja2.FileSystemLoader(f"{repo}/faa-demo/templates"))
open(f"{out}/index.html", "w").write(env.get_template("index.html.j2").render(decks=decks))
for d in decks:
    os.makedirs(f"{out}/{d['name']}", exist_ok=True)
    for src, dest in (("slides/index.html", "index.html"), ("images", "images")):
        link = f"{out}/{d['name']}/{dest}"
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(f"{repo}/{d['name']}/{src}", link)
EOF

echo "Slides: http://localhost:${PORT}/   (Ctrl-C to stop)"
# Like "python -m http.server", but tells the browser not to cache: a normal
# refresh then always shows the latest edit (no forced reload needed)
cd "${OUT}"
exec "${REPO}/.venv/bin/python" - "${PORT}" <<'PY'
import http.server, sys
class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), NoCache).serve_forever()
PY
