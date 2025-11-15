#!/usr/bin/env bash
set -e
set -o pipefail

echo "==============================================="
echo "     Perjury Dispatcher — Automated Installer"
echo "          Ubuntu / AWS EC2 (HTTP-only)"
echo "==============================================="

# --------------------------------------------------------------------
# REQUIRE ROOT
# --------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ ERROR: Please run as root:"
    echo "   sudo bash install.sh"
    exit 1
fi

# --------------------------------------------------------------------
# PATHS
# --------------------------------------------------------------------
DISPATCHER_DIR="/opt/dispatcher"
APP_DIR="$DISPATCHER_DIR/perjury_app"
VENV_DIR="$APP_DIR/venv"
SYSTEMD_UNIT="/etc/systemd/system/perjury.service"
NGINX_CONF="/etc/nginx/conf.d/perjury.conf"
MAIN_FILE="$DISPATCHER_DIR/main.py"

echo "📦 Installing required system packages..."
apt update -y
apt install -y python3 python3-venv python3-pip nginx unzip git

# --------------------------------------------------------------------
# INSTALL APPLICATION CODE
# --------------------------------------------------------------------
echo "📁 Preparing dispatcher directory..."
mkdir -p "$DISPATCHER_DIR"

echo "📦 Copying project files into place..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -R . "$APP_DIR"

# --------------------------------------------------------------------
# CREATE DISPATCHER main.py
# --------------------------------------------------------------------
echo "📝 Generating /opt/dispatcher/main.py ..."

cat > "$MAIN_FILE" <<EOF
# Auto-generated WSGI entrypoint for Gunicorn
from perjury_app.app import create_app
app = create_app()
EOF

# --------------------------------------------------------------------
# PYTHON VENV
# --------------------------------------------------------------------
echo "🐍 Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

if [[ -f "$APP_DIR/requirements.txt" ]]; then
    echo "📦 Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/requirements.txt"
else
    echo "⚠️ requirements.txt missing — installing flask + gunicorn"
    pip install flask gunicorn
fi

deactivate

# --------------------------------------------------------------------
# PERMISSIONS
# --------------------------------------------------------------------
echo "🔐 Setting permissions for www-data..."
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

# --------------------------------------------------------------------
# SYSTEMD SERVICE
# --------------------------------------------------------------------
echo "📝 Creating systemd service at $SYSTEMD_UNIT ..."

cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=Perjury Dispatcher (Gunicorn)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$DISPATCHER_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$APP_DIR/perjury.sock "main:app"
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd + restarting service..."
systemctl daemon-reload
systemctl enable perjury
systemctl restart perjury || true

sleep 2
systemctl status perjury --no-pager || true

# --------------------------------------------------------------------
# NGINX CONFIG
# --------------------------------------------------------------------
echo "🛠️ Removing default Nginx site..."
rm -f /etc/nginx/sites-enabled/default

echo "🌐 Writing Nginx config to $NGINX_CONF..."

cat > "$NGINX_CONF" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    access_log /var/log/nginx/perjury_access.log;
    error_log  /var/log/nginx/perjury_error.log;

    # Health check
    location = /health {
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    # Landing page
    location = / {
        add_header Content-Type text/html;
        return 200 "<h2>Perjury Host Installed</h2><p>Try <a href='/perjury/'>/perjury/</a></p>\n";
    }

    # Dispatcher → Gunicorn via Unix socket
    location /perjury/ {
        proxy_pass http://unix:$APP_DIR/perjury.sock/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "🔍 Testing Nginx configuration..."
nginx -t

echo "🔄 Restarting Nginx..."
systemctl restart nginx

echo ""
echo "==============================================="
echo " 🎉 INSTALLATION COMPLETE"
echo "==============================================="
echo "Visit:   http://<server-ip>/perjury/"
echo "Health:  http://<server-ip>/health"
echo ""
echo "LOGS:"
echo "  systemctl status perjury"
echo "  journalctl -u perjury -f"
echo "  tail -f /var/log/nginx/perjury_error.log"
echo "==============================================="

