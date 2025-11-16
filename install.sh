#!/usr/bin/env bash
set -e
set -o pipefail

echo "==============================================="
echo "  Perjury App Installer / Updater"
echo "  Safe to run multiple times"
echo "==============================================="

# ------------------------------
# CHECK ROOT
# ------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ ERROR: Please run as root (sudo ./install.sh)"
    exit 1
fi

DISPATCHER_DIR="/opt/dispatcher"
APP_DIR="$DISPATCHER_DIR/perjury_app"
VENV_DIR="$APP_DIR/venv"
SYSTEMD_FILE="/etc/systemd/system/perjury.service"
NGINX_CONF="/etc/nginx/conf.d/perjury.conf"

# ------------------------------
# INSTALL DEPENDENCIES
# ------------------------------
echo "🔧 Installing required packages..."
apt update -y
apt install -y python3 python3-venv python3-pip nginx git unzip

# ------------------------------
# COPY UPDATED APPLICATION CODE
# ------------------------------
echo "📁 Preparing dispatcher directory..."
mkdir -p "$DISPATCHER_DIR"

echo "📦 Updating application files in $APP_DIR ..."
mkdir -p "$APP_DIR"

# Preserve data directory
echo "🔒 Preserving existing /data folder if present..."
if [[ -d "$APP_DIR/data" ]]; then
    mv "$APP_DIR/data" /tmp/perjury_data_backup_$$
fi

# Replace app contents
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -R . "$APP_DIR"

# Restore data
if [[ -d "/tmp/perjury_data_backup_$$" ]]; then
    echo "♻️ Restoring preserved data folder..."
    mv "/tmp/perjury_data_backup_$$" "$APP_DIR/data"
fi

echo "👤 Setting permissions..."
chown -R www-data:www-data "$APP_DIR"
chmod -R 755 "$APP_DIR"

# ------------------------------
# PYTHON VENV (REUSED IF EXISTS)
# ------------------------------
if [[ ! -d "$VENV_DIR" ]]; then
    echo "🐍 Creating new Python virtual environment..."
    python3 -m venv "$VENV_DIR"
else
    echo "🐍 Using existing Python virtual environment..."
fi

echo "📦 Installing / updating Python dependencies..."
source "$VENV_DIR/bin/activate"

if [[ -f "$APP_DIR/requirements.txt" ]]; then
    pip install --upgrade pip
    pip install -r "$APP_DIR/requirements.txt"
else
    pip install --upgrade pip
    pip install flask gunicorn
fi

deactivate

# ------------------------------
# SYSTEMD SERVICE
# ------------------------------
echo "📝 Updating systemd service: $SYSTEMD_FILE"

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
sleep 1

# ------------------------------
# NGINX CONFIG (UPDATED + BACKUP)
# ------------------------------
echo "🌐 Updating NGINX configuration: $NGINX_CONF"

if [[ -f "$NGINX_CONF" ]]; then
    cp "$NGINX_CONF" "$NGINX_CONF.bak-$(date +%s)"
    echo "🔒 Backed up old NGINX config."
fi

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

    # Avoid favicon spam
    location = /favicon.ico {
        empty_gif;
    }

    # Convenience redirect so /perjury -> /perjury/
    location = /perjury {
        return 301 /perjury/;
    }

    # Landing page
    location = / {
        add_header Content-Type text/html;
        return 200 "<h2>Perjury Host Installed</h2><p>Open <a href='/perjury/'>/perjury/</a></p>\n";
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

echo "🔍 Testing NGINX config..."
nginx -t

echo "🔄 Restarting NGINX..."
systemctl restart nginx

# ------------------------------
# FINAL STATUS
# ------------------------------
echo "==============================================="
echo " 🎉 Perjury install/update complete!"
echo "==============================================="
echo "App URL:   http://<server-ip>/perjury/"
echo "Health:    http://<server-ip>/health"
echo ""
echo "Useful commands:"
echo "  systemctl status perjury"
echo "  journalctl -u perjury -f"
echo "  tail -f /var/log/nginx/perjury_error.log"
echo "==============================================="
