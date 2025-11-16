#!/usr/bin/env bash
set -e
set -o pipefail

echo "==============================================="
echo "  Perjury App Installer"
echo "  Installing on Ubuntu (e.g. AWS EC2)"
echo "==============================================="

# Must run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ ERROR: Please run as root (sudo ./install.sh)"
    exit 1
fi

DISPATCHER_DIR="/opt/dispatcher"
APP_DIR="$DISPATCHER_DIR/perjury_app"
VENV_DIR="$APP_DIR/venv"
SYSTEMD_FILE="/etc/systemd/system/perjury.service"
NGINX_CONF="/etc/nginx/conf.d/perjury.conf"

echo "🔧 Installing required packages..."
apt update -y
apt install -y python3 python3-venv python3-pip nginx git unzip

# ------------------------------------------------------------------------------
# COPY REPO INTO /opt/dispatcher
# ------------------------------------------------------------------------------

echo "📁 Preparing dispatcher directory at $DISPATCHER_DIR ..."
mkdir -p "$DISPATCHER_DIR"

echo "📦 Copying Perjury app into $APP_DIR ..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -R . "$APP_DIR"

echo "👤 Setting ownership and permissions..."
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

# ------------------------------------------------------------------------------
# PYTHON VENV
# ------------------------------------------------------------------------------

echo "🐍 Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"

source "$VENV_DIR/bin/activate"

if [[ -f "$APP_DIR/requirements.txt" ]]; then
    echo "📦 Installing Python dependencies from requirements.txt ..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/requirements.txt"
else
    echo "⚠️ WARNING: requirements.txt not found — installing flask + gunicorn"
    pip install --upgrade pip
    pip install flask gunicorn
fi

deactivate

# ------------------------------------------------------------------------------
# OPTIONAL: create a simple main.py entrypoint (for debugging)
# ------------------------------------------------------------------------------

MAIN_PY="$DISPATCHER_DIR/main.py"
echo "📝 Writing $MAIN_PY (debug entrypoint)..."
cat > "$MAIN_PY" << 'EOF'
from perjury_app.app import create_app

app = create_app()

if __name__ == "__main__":
    # Simple dev server (not for production)
    app.run(host="0.0.0.0", port=5000, debug=True)
EOF

chown www-data:www-data "$MAIN_PY"
chmod 755 "$MAIN_PY"

# ------------------------------------------------------------------------------
# SYSTEMD SERVICE (Gunicorn)
# ------------------------------------------------------------------------------

echo "📝 Creating systemd service at $SYSTEMD_FILE ..."

cat > "$SYSTEMD_FILE" <<EOF
[Unit]
Description=Perjury Dispatcher (Gunicorn)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$DISPATCHER_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$APP_DIR/perjury.sock perjury_app.app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd..."
systemctl daemon-reload
systemctl enable perjury
systemctl restart perjury || true

sleep 2
systemctl status perjury --no-pager || true

# ------------------------------------------------------------------------------
# NGINX CONFIGURATION
# ------------------------------------------------------------------------------

echo "🛠️ Disabling Ubuntu default nginx site (if present)..."
if [[ -f /etc/nginx/sites-enabled/default ]]; then
    rm -f /etc/nginx/sites-enabled/default
fi

echo "🌐 Writing Nginx config to $NGINX_CONF ..."

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

    # Convenience redirect so /perjury -> /perjury/
    location = /perjury {
        return 301 /perjury/;
    }

    # Landing page
    location = / {
        add_header Content-Type text/html;
        return 200 "<h2>Perjury Host Installed</h2><p>Try <a href='/perjury/'>/perjury/</a></p>\n";
    }

    # Proxy all /perjury/* to Gunicorn (Unix socket)
    location /perjury/ {
        proxy_pass http://unix:$APP_DIR/perjury.sock:;
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

# ------------------------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------------------------

echo "==============================================="
echo " 🎉 Installation Complete!"
echo "==============================================="
echo ""
echo "App URL:   http://<server-ip>/perjury/"
echo "Health:    http://<server-ip>/health"
echo ""
echo "Useful commands:"
echo "  systemctl status perjury"
echo "  journalctl -u perjury -f"
echo "  tail -f /var/log/nginx/perjury_error.log"
echo "==============================================="
