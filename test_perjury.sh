#!/usr/bin/env bash
set -e
set -o pipefail

OUT="/tmp/perjury_diagnostics.txt"
SOCK="/opt/dispatcher/perjury_app/perjury.sock"

echo "Running Perjury diagnostics..."
echo "Output: $OUT"
echo "" > "$OUT"

SECTION() {
    echo "===================================================" | tee -a "$OUT"
    echo "== $1" | tee -a "$OUT"
    echo "===================================================" | tee -a "$OUT"
}

# --------------------------------------------------------------------
SECTION "SYSTEM INFO"
# --------------------------------------------------------------------
{
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "Uptime: $(uptime)"
    echo ""
} >> "$OUT"

# --------------------------------------------------------------------
SECTION "CHECKING SOCKET FILE"
# --------------------------------------------------------------------
{
    if [[ -S "$SOCK" ]]; then
        echo "✔ Socket exists: $SOCK"
        ls -l "$SOCK"
    else
        echo "❌ Socket NOT FOUND: $SOCK"
    fi
    echo ""
} >> "$OUT"

# --------------------------------------------------------------------
SECTION "SYSTEMD STATUS (perjury)"
# --------------------------------------------------------------------
systemctl status perjury --no-pager --full 2>&1 | tee -a "$OUT"

# --------------------------------------------------------------------
SECTION "RECENT SYSTEMD LOGS (perjury)"
# --------------------------------------------------------------------
journalctl -u perjury -n 200 --no-pager 2>&1 | tee -a "$OUT"

# --------------------------------------------------------------------
SECTION "NGINX CONFIG DUMP"
# --------------------------------------------------------------------
cat /etc/nginx/conf.d/perjury.conf 2>&1 | tee -a "$OUT"

# --------------------------------------------------------------------
SECTION "NGINX ERROR LOG"
# --------------------------------------------------------------------
sudo tail -n 200 /var/log/nginx/error.log 2>&1 | tee -a "$OUT"

# --------------------------------------------------------------------
SECTION "PERJURY ERROR LOG"
# --------------------------------------------------------------------
sudo tail -n 200 /var/log/nginx/perjury_error.log 2>&1 | tee -a "$OUT"

# --------------------------------------------------------------------
SECTION "CURL ENDPOINT TESTS"
# --------------------------------------------------------------------
BASE="http://127.0.0.1/perjury"

{
    echo "Testing endpoints at: $BASE"
    echo ""

    test_url() {
        echo "---- GET $1 ----"
        curl -I "$1" 2>&1
        curl -s "$1" | head -n 20
        echo ""
    }

    test_url "$BASE/"
    test_url "$BASE/login"
    test_url "$BASE/control/"
    test_url "$BASE/whoami"
    test_url "$BASE/static/admin.css"
} >> "$OUT"

# --------------------------------------------------------------------
SECTION "SOCKET DIRECT ACCESS TEST"
# --------------------------------------------------------------------
{
    echo "Trying direct socket request:"
    curl --unix-socket "$SOCK" http://localhost/ -v 2>&1
    echo ""
} >> "$OUT"

# --------------------------------------------------------------------
SECTION "DONE"
# --------------------------------------------------------------------
echo "Diagnostics complete." | tee -a "$OUT"
echo ""
echo "Upload the file below back here:"
echo "     $OUT"
echo ""
