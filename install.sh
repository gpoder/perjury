#!/usr/bin/env bash
set -e
set -o pipefail

echo "==============================================="
echo "  Perjury App Installer"
echo "  Ubuntu / AWS EC2 - Zero Config"
echo "==============================================="

if [[ "$EUID" -ne 0 ]]; then
    echo "❌ ERROR: Run as root:   sudo ./install.sh"
    exit 1
fi

DISPATCHER_DIR="/opt/dispatcher"
APP_DIR="$DISPATCHER_DIR/perjury_app"
VENV_DIR="$APP_DIR/venv"
SYSTEMD_FILE="/etc/systemd/system/perjury.service"
NGINX_CONF="/etc/nginx/conf.d/perjury.conf"

echo "🔧 Installing required packages..."
apt update -y
apt install -y python3 python3-venv python3-pip nginx unzip git

echo "📁 Preparing /opt/dispatcher..."
mkdir -p "$DISPATCHER_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"

echo "📦 Copying project into /opt/dispatcher/perjury_app..."
cp -R . "$APP_DIR"

# --------------------------------------------------------
#  CREATE PYTHON VENV
# --------------------------------------------------------
echo "🐍 Creating virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

if [[ -f "$APP_DIR/requirements.txt" ]]; then
    pip install --upgrade pip
    pip install -r "$APP_DIR/requirements.txt"
else
    pip install flask gunicorn
fi

deactivate

# --------------------------------------------------------
#  CREATE main.py (WSGI loader)
# --------------------------------------------------------

echo "📝 Writing /opt/dispatcher/main.py..."

cat > "$DISPATCHER_DIR/main.py" <<EOF
from perjury_app.app import app

if __name__ == "__main__":
    app.run()
EOF

# --------------------------------------------------------
#  FIX PERMISSIONS
# --------------------------------------------------------
echo "🔐 Setting permissions for www-data..."

chown -R www-data:www-data "$DISPATCHER_DIR"
chmod -R 755 "$DISPATCHER_DIR"

# --------------------------------------------------------
#  SYSTEMD SERVICE
# --------------------------------------------------------
echo "📝 Creating systemd unit at $SYSTEMD_FILE..."

cat > "$SYSTEMD_FILE" <<EOF
[Unit]
Description=Perjury Dispatcher (Gunicorn)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$DISPATCHER_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --chdir $DISPATCHER_DIR --workers 3 --bind unix:$APP_DIR/perjury.sock main:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd..."
systemctl daemon-reload
systemctl enable perjury
systemctl restart perjury

sleep 2
systemctl status perjury --no-pager || true

# --------------------------------------------------------
#  NGINX CONFIG
# --------------------------------------------------------

echo "🛠️ Disabling default nginx site..."
rm -f /etc/nginx/sites-enabled/default

echo "🌐 Writing Nginx config..."

cat > "$NGINX_CONF" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    access_log /var/log/nginx/perjury_access.log;
    error_log  /var/log/nginx/perjury_error.log;

    # STATIC FILES (properly routed)
    location /perjury/static/ {
        alias $APP_DIR/static/;
    }

    # Health check
    location = /health {
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    # Landing page
    location = / {
        add_header Content-Type text/html;
        return 200 "<h2>Perjury Host Installed</h2><p>Go to <a href='/perjury/'>/perjury/</a></p>\n";
    }

    # Dispatcher → Flask via Gunicorn (Unix socket)
    location /perjury/ {
        rewrite ^/perjury/(.*)$ /$1 break;
        proxy_pass http://unix:$APP_DIR/perjury.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "🔍 Testing Nginx..."
nginx -t

echo "🔄 Restarting Nginx..."
systemctl restart nginx

# --------------------------------------------------------
#  DONE
# --------------------------------------------------------

echo "==============================================="
echo " 🎉 Installation Complete!"
echo "==============================================="
echo "Visit:    http://<server-ip>/perjury/"
echo "Health:   http://<server-ip>/health"
echo ""
echo "Logs:"
echo "  systemctl status perjury"
echo "  journalctl -u perjury -f"
echo "  tail -f /var/log/nginx/perjury_error.log"
echo ""
echo "==============================================="

